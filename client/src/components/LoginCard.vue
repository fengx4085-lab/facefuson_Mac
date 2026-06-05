<template>
  <div class="login-card">
    <h1 class="title">欢迎登录</h1>
    <p class="subtitle">使用手机号验证码快速登录</p>

    <PhoneInput
      v-model="phone"
      :area-code="areaCode"
      :error="phoneError"
      @update:area-code="areaCode = $event"
      @blur="validatePhone"
    />

    <CodeInput
      v-model="code"
      :cooldown="codeCooldown"
      :disabled="!isPhoneValid"
      :error="codeError"
      @send="handleSendCode"
      @blur="validateCode"
    />

    <div v-if="devCode" class="dev-hint">
      验证码（开发环境）：{{ devCode }}
    </div>

    <GradientButton :loading="loading" @click="handleLogin">
      登 录
    </GradientButton>

    <p class="agreement">
      登录即同意 <a href="#">用户协议</a> 和 <a href="#">隐私政策</a>
    </p>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import PhoneInput from './PhoneInput.vue'
import CodeInput from './CodeInput.vue'
import GradientButton from './GradientButton.vue'
import { useAuth } from '@/composables/useAuth'

const { loading, error: authError, codeCooldown, sendCode, login } = useAuth()

const phone = ref('')
const areaCode = ref('+86')
const code = ref('')
const devCode = ref('')
const phoneError = ref('')
const codeError = ref('')

const isPhoneValid = computed(() => /^\d{11}$/.test(phone.value))

function validatePhone() {
  if (!phone.value) {
    phoneError.value = '请输入手机号'
  } else if (!/^\d{11}$/.test(phone.value)) {
    phoneError.value = '请输入正确的手机号'
  } else {
    phoneError.value = ''
  }
}

function validateCode() {
  if (code.value && !/^\d{6}$/.test(code.value)) {
    codeError.value = '验证码格式不正确'
  } else {
    codeError.value = ''
  }
}

async function handleSendCode() {
  validatePhone()
  if (phoneError.value) return

  const result = await sendCode(phone.value, areaCode.value)
  if (result) {
    devCode.value = result
  }
}

async function handleLogin() {
  validatePhone()
  validateCode()

  if (phoneError.value || codeError.value) return
  if (!code.value) {
    codeError.value = '请输入验证码'
    return
  }

  await login(phone.value, areaCode.value, code.value)
  if (authError.value) {
    codeError.value = authError.value
  }
}
</script>

<style scoped>
.login-card {
  width: 400px;
  max-width: 90vw;
  padding: 40px 36px;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  gap: 18px;
  position: relative;
  z-index: 1;
}

.title {
  font-size: 26px;
  font-weight: 700;
  background: linear-gradient(135deg, #4f7cff, #a855f7);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  text-align: center;
}

.subtitle {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.5);
  text-align: center;
  margin-bottom: 8px;
}

.dev-hint {
  padding: 10px 14px;
  background: rgba(79, 124, 255, 0.1);
  border: 1px solid rgba(79, 124, 255, 0.2);
  border-radius: 8px;
  color: #4f7cff;
  font-size: 13px;
  text-align: center;
}

.agreement {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.35);
  text-align: center;
}

.agreement a {
  color: rgba(255, 255, 255, 0.5);
  text-decoration: none;
}

.agreement a:hover {
  text-decoration: underline;
}
</style>
