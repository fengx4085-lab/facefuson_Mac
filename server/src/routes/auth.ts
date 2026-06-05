import { Router, Request, Response } from 'express'
import { generateCode, verifyCode } from '../services/codeStore'
import { signToken } from '../utils/jwt'

const router = Router()

router.post('/send-code', (req: Request, res: Response) => {
  const { phone, areaCode } = req.body

  if (!phone || !/^\d{11}$/.test(phone)) {
    return res.status(400).json({ success: false, message: '请输入正确的手机号' })
  }

  const result = generateCode(phone)

  if (result.waitSeconds) {
    return res.status(429).json({
      success: false,
      message: `请求过于频繁，请 ${result.waitSeconds} 秒后再试`,
    })
  }

  // 开发环境：在响应中返回验证码方便调试
  res.json({ success: true, code: result.code })
})

router.post('/login', (req: Request, res: Response) => {
  const { phone, areaCode, code } = req.body

  if (!phone || !/^\d{11}$/.test(phone)) {
    return res.status(400).json({ success: false, message: '请输入正确的手机号' })
  }
  if (!code || !/^\d{6}$/.test(code)) {
    return res.status(400).json({ success: false, message: '验证码格式不正确' })
  }

  const isValid = verifyCode(phone, code)

  if (!isValid) {
    return res.status(401).json({ success: false, message: '验证码错误或已过期' })
  }

  const token = signToken({ phone, areaCode: areaCode || '+86' })

  res.json({
    success: true,
    token,
    user: {
      id: `user_${phone.slice(-4)}`,
      phone,
      areaCode: areaCode || '+86',
    },
  })
})

export default router
