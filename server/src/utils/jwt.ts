import jwt from 'jsonwebtoken'

const SECRET = process.env.JWT_SECRET || 'dev-secret-key'
const EXPIRES_IN = '24h'

export function signToken(payload: { phone: string; areaCode: string }): string {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN })
}

export function verifyToken(token: string): { phone: string; areaCode: string } | null {
  try {
    return jwt.verify(token, SECRET) as { phone: string; areaCode: string }
  } catch {
    return null
  }
}
