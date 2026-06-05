import { ref, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'

export function useAuth() {
  const router = useRouter()
  const loading = ref(false)
  const error = ref('')
  const codeCooldown = ref(0)
  let cooldownTimer: ReturnType<typeof setInterval> | null = null

  onUnmounted(() => {
    if (cooldownTimer) clearInterval(cooldownTimer)
  })

  async function sendCode(phone: string, areaCode: string): Promise<string | null> {
    error.value = ''

    try {
      const res = await fetch('/api/send-code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, areaCode }),
      })
      const data = await res.json()

      if (!data.success) {
        error.value = data.message
        return null
      }

      startCooldown()
      return data.code // 开发环境返回验证码
    } catch {
      error.value = '网络错误，请稍后再试'
      return null
    }
  }

  async function login(phone: string, areaCode: string, code: string) {
    error.value = ''
    loading.value = true

    try {
      const res = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, areaCode, code }),
      })
      const data = await res.json()

      if (!data.success) {
        error.value = data.message
        return
      }

      localStorage.setItem('token', data.token)
      localStorage.setItem('phone', data.user.phone)
      router.push('/home')
    } catch {
      error.value = '网络错误，请稍后再试'
    } finally {
      loading.value = false
    }
  }

  function startCooldown() {
    codeCooldown.value = 60
    if (cooldownTimer) clearInterval(cooldownTimer)
    cooldownTimer = setInterval(() => {
      codeCooldown.value--
      if (codeCooldown.value <= 0) {
        clearInterval(cooldownTimer!)
        cooldownTimer = null
      }
    }, 1000)
  }

  return {
    loading,
    error,
    codeCooldown,
    sendCode,
    login,
  }
}
