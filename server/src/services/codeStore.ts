interface CodeEntry {
  code: string
  expiresAt: number
  lastSentAt: number
}

const store = new Map<string, CodeEntry>()

const CODE_EXPIRE_MS = 5 * 60 * 1000 // 5 分钟
const RESEND_COOLDOWN_MS = 60 * 1000  // 60 秒

export function generateCode(phone: string): { code: string; waitSeconds?: number } {
  const key = phone
  const now = Date.now()
  const existing = store.get(key)

  if (existing && now - existing.lastSentAt < RESEND_COOLDOWN_MS) {
    const waitSeconds = Math.ceil((RESEND_COOLDOWN_MS - (now - existing.lastSentAt)) / 1000)
    return { code: '', waitSeconds }
  }

  const code = String(Math.floor(100000 + Math.random() * 900000))
  store.set(key, {
    code,
    expiresAt: now + CODE_EXPIRE_MS,
    lastSentAt: now,
  })
  return { code }
}

export function verifyCode(phone: string, inputCode: string): boolean {
  const key = phone
  const entry = store.get(key)

  if (!entry) return false
  if (Date.now() > entry.expiresAt) {
    store.delete(key)
    return false
  }
  if (entry.code !== inputCode) return false

  store.delete(key)
  return true
}
