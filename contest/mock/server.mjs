import http from 'node:http';

const scenarios = new Map();
const counts = { requests: 0, toolResults: 0 };
const server = http.createServer(async (req, res) => {
  const reply = (status, value) => {
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(value));
  };
  try {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 1048576) return reply(413, { error: 'Request too large' });
      chunks.push(chunk);
    }
    const body = chunks.length ? JSON.parse(Buffer.concat(chunks)) : {};
    if (req.url === '/health') return reply(200, { mock: true, ...counts });
    // Test control is network-internal and never exposed on a host port.
    if (req.url === '/scenario' && req.method === 'POST') {
      scenarios.set('next', body.mode);
      return reply(200, { ok: true });
    }
    if (req.url !== '/v1/chat/completions') return reply(404, { error: 'Not found' });
    counts.requests++;
    const user = body.messages.findLast(message => message.role === 'user');
    const { case_id: caseId } = JSON.parse(user.content);
    if (!scenarios.has(String(caseId)) && scenarios.has('next')) {
      scenarios.set(String(caseId), scenarios.get('next'));
      scenarios.delete('next');
    }
    const mode = scenarios.get(String(caseId));
    if (mode === 'provider_error') return reply(503, { error: { message: 'Injected mock failure', type: 'server_error' } });
    const tool = body.messages.findLast(message => message.role === 'tool');
    let message;
    if (!tool && mode === 'skip_tool') {
      message = { role: 'assistant', content: JSON.stringify({ decision: 'deliver', reason: 'Skipped fact tool' }) };
    } else if (!tool) {
      const definition = body.tools?.find(item => item.function.name.endsWith('GetTriageFacts'));
      if (!definition) return reply(400, { error: { message: 'AI Hub did not advertise the fact tool' } });
      message = { role: 'assistant', content: null, tool_calls: [
        { id: `facts-${caseId}`, type: 'function', function: {
          name: definition.function.name, arguments: JSON.stringify({ caseId: mode === 'wrong_case' ? '999999999' : String(caseId) })
        } }
      ] };
    } else {
      counts.toolResults++;
      const facts = JSON.parse(tool.content);
      if (typeof facts.has_required_fields !== 'boolean' || typeof facts.known_code !== 'boolean') {
        return reply(400, { error: { message: 'Fact tool failed or returned invalid facts' } });
      }
      let decision = !facts.has_required_fields ? 'quarantine' : !facts.known_code ? 'human_review' : 'deliver';
      if (mode === 'unsafe_deliver') decision = 'deliver';
      if (mode === 'unknown_action') decision = 'delete_production';
      const reason = mode === 'empty_reason' ? '' : 'Synthetic mock decision from deterministic facts, not real model inference.';
      message = { role: 'assistant', content: mode === 'invalid_json' ? 'not JSON'
        : mode === 'wrong_type' ? JSON.stringify({ decision: 42, reason })
        : JSON.stringify({ decision, reason }) };
    }
    reply(200, { id: `mock-${counts.requests}`, object: 'chat.completion', created: 1,
      model: body.model, choices: [{ index: 0, message, finish_reason: tool ? 'stop' : 'tool_calls' }],
      usage: { prompt_tokens: 10, completion_tokens: 10, total_tokens: 20 }
    });
  } catch (error) {
    console.error(error.message);
    reply(400, { error: { message: error.message } });
  }
});
server.listen(8088, '0.0.0.0', () => console.log('Synthetic mock provider listening on 8088'));
