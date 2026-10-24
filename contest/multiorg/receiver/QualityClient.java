import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;

// Source-file execution uses the JDBC driver bundled with this IRIS installation.
class QualityClient {
    private static boolean sqlCode(SQLException exception, int code) {
        return Math.abs(exception.getErrorCode()) == Math.abs(code)
                || (exception.getMessage() != null
                && exception.getMessage().contains("[SQLCODE: <" + code + ">"));
    }

    public static void main(String[] args) throws Exception {
        Properties credentials = new Properties();
        try (Reader reader = Files.newBufferedReader(
                Path.of("/dur/multiorg-receiver/quality.properties"))) {
            credentials.load(reader);
        }
        BufferedReader input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
        String[] p = new String[7];
        for (int i = 0; i < p.length; i++) {
            p[i] = new String(Base64.getDecoder().decode(input.readLine()), StandardCharsets.UTF_8);
        }
        DriverManager.setLoginTimeout(5);
        Class.forName("com.intersystems.jdbc.IRISDriver");
        Properties props = new Properties();
        props.setProperty("user", credentials.getProperty("user"));
        props.setProperty("password", credentials.getProperty("password"));
        props.setProperty("queryTimeout", "5");
        props.setProperty("timeout", "5");
        try (Connection connection = DriverManager.getConnection(
                "jdbc:IRIS://127.0.0.1:1972/DEMOQUALITY", props)) {
            connection.setAutoCommit(true);
            if (p[0].equals("permissions")) {
                try (Statement statement = connection.createStatement()) {
                    statement.setQueryTimeout(5);
                    try {
                        statement.executeUpdate("UPDATE MultiOrg_Receiver.Receipt SET status='changed' WHERE 1=0");
                        throw new IllegalStateException("Unexpected UPDATE privilege");
                    } catch (SQLException exception) {
                        if (!sqlCode(exception, -99)) throw exception;
                    }
                    try {
                        statement.executeUpdate("DELETE FROM MultiOrg_Receiver.Receipt WHERE 1=0");
                        throw new IllegalStateException("Unexpected DELETE privilege");
                    } catch (SQLException exception) {
                        if (!sqlCode(exception, -99)) throw exception;
                    }
                }
                System.out.println("PERMISSIONS-OK");
                return;
            }
            boolean duplicate = false;
            if (p[0].equals("send")) {
                try (PreparedStatement statement = connection.prepareStatement(
                        "INSERT INTO MultiOrg_Receiver.Receipt "
                        + "(DeliveryId,PayloadHash,RawPayload,patient_id,birthYear,status) VALUES (?,?,?,?,?,?)")) {
                    statement.setQueryTimeout(5);
                    statement.setString(1, p[1]); statement.setString(2, p[3]);
                    statement.setString(3, p[2]); statement.setString(4, p[4]);
                    statement.setInt(5, Integer.parseInt(p[5])); statement.setString(6, p[6]);
                    try {
                        statement.executeUpdate();
                    } catch (SQLException exception) {
                        if (!sqlCode(exception, -119) && !"23000".equals(exception.getSQLState()))
                            throw exception;
                        duplicate = true;
                    }
                }
            }
            try (PreparedStatement statement = connection.prepareStatement(
                    "SELECT RawPayload,PayloadHash,patient_id,birthYear,status "
                    + "FROM MultiOrg_Receiver.Receipt WHERE DeliveryId=?")) {
                statement.setQueryTimeout(5);
                statement.setString(1, p[1]);
                try (ResultSet result = statement.executeQuery()) {
                    if (!result.next()) {
                        if (p[0].equals("send")) throw new SQLException("Missing committed receipt");
                        System.out.println("MISSING");
                        return;
                    }
                    String raw = result.getString(1);
                    String hash = result.getString(2);
                    byte[] actual = MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8));
                    StringBuilder hex = new StringBuilder();
                    for (byte b : actual) hex.append(String.format("%02x", b & 255));
                    if (!hex.toString().equals(hash)) throw new SQLException("Corrupt receiver digest");
                    if (p[0].equals("send") && (!raw.equals(p[2]) || !hash.equals(p[3])
                            || !result.getString(3).equals(p[4]) || result.getInt(4) != Integer.parseInt(p[5])
                            || !result.getString(5).equals(p[6]))) {
                        throw new SQLException("Delivery ID body conflict");
                    }
                    System.out.println(Base64.getEncoder().encodeToString(raw.getBytes(StandardCharsets.UTF_8)));
                    System.out.println(duplicate ? "DUPLICATE" : "STORED");
                    System.out.println(Base64.getEncoder().encodeToString(result.getString(3).getBytes(StandardCharsets.UTF_8)));
                    System.out.println(Base64.getEncoder().encodeToString(Integer.toString(result.getInt(4)).getBytes(StandardCharsets.UTF_8)));
                    System.out.println(Base64.getEncoder().encodeToString(result.getString(5).getBytes(StandardCharsets.UTF_8)));
                }
            }
        }
    }
}
