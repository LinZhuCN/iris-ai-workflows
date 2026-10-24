export interface KnowledgeStatus {
  ready: boolean
  documents: number
  chunks: number
  dimensions: number
  model: string
  latestJob: string
  canBuild: boolean
  user: string
  corpusId: string
  indexVersion: string
}
export interface KnowledgeHit {
  text: string
  score: number
  title: string
  url: string
  locator: string
  scope: string
}
export interface KnowledgeJob {
  id: string; state: string; documents: number; expected: number
  stage: string; error: string; started: string; completed: string
}
function object(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Invalid Knowledge API object')
  return value as Record<string, unknown>
}
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid Knowledge API text')
  return value
}
function number(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new Error('Invalid Knowledge API number')
  return value
}
function flag(value: unknown): boolean {
  if (value === true || value === 1) return true
  if (value === false || value === 0) return false
  throw new Error('Invalid Knowledge API flag')
}
export function decodeKnowledge(value: unknown): KnowledgeStatus {
  const v = object(value)
  return {
    ready: flag(v.ready), documents: number(v.documents), chunks: number(v.chunks),
    dimensions: number(v.dimensions), model: text(v.model), latestJob: String(v.latest_job),
    canBuild: flag(v.can_build), user: text(v.user), corpusId: text(v.corpus_id), indexVersion: String(v.index_version),
  }
}
export function decodeHits(value: unknown): { hits: KnowledgeHit[]; version: string } {
  const v = object(value)
  if (!Array.isArray(v.value)) throw new Error('Invalid retrieval results')
  return { version: String(v.index_version), hits: v.value.map(item => {
    const hit = object(item), meta = object(hit.metadata)
    const url = text(meta.source_url)
    const parsed = new URL(url)
    if (parsed.protocol !== 'https:') throw new Error('Unsafe evidence URL')
    return {
      text: text(hit.text), score: number(hit.score), title: text(meta.title),
      url, locator: text(meta.source_locator), scope: text(meta.retrieval_scope),
    }
  }) }
}
export function decodeJob(value: unknown): KnowledgeJob {
  const v = object(value)
  return {
    id: String(v.id), state: text(v.state), documents: Number(v.documents || 0),
    expected: number(v.expected), stage: text(v.stage), error: text(v.error),
    started: text(v.started), completed: text(v.completed),
  }
}
export function decodeJobId(value: unknown): string {
  const id = object(value).job_id
  if (!/^[0-9]+$/.test(String(id))) throw new Error('Invalid build job ID')
  return String(id)
}
