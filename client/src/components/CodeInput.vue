<template>
  <div class="code-input-wrapper">
    <div class="input-row">
      <input
        type="text"
        :value="modelValue"
        placeholder="请输入验证码"
        maxlength="6"
        inputmode="numeric"
        @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value.replace(/\D/g, ''))"
        @blur="$emit('blur')"
      />
      <button
        class="send-btn"
        :disabled="cooldown > 0 || disabled"
        @click="$emit('send')"
      >
        {{ cooldown > 0 ? `${cooldown}s` : '获取验证码' }}
      </button>
    </div>
    <p v-if="error" class="error-msg">{{ error }}</p>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  modelValue: string
  cooldown: number
  disabled?: boolean
  error?: string
}>()

defineEmits<{
  'update:modelValue': [value: string]
  send: []
  blur: []
}>()
</script>

<style scoped>
.code-input-wrapper {
  width: 100%;
}

.input-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

input {
  flex: 1;
  padding: 14px 16px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: #fff;
  font-size: 15px;
  letter-spacing: 4px;
  outline: none;
  transition: border-color 0.2s;
}

input::placeholder {
  color: rgba(255, 255, 255, 0.3);
  letter-spacing: 0;
}

input:focus {
  border-image: linear-gradient(135deg, #4f7cff, #a855f7) 1;
}

.send-btn {
  padding: 14px 18px;
  background: rgba(79, 124, 255, 0.15);
  border: 1px solid rgba(79, 124, 255, 0.3);
  border-radius: 10px;
  color: #4f7cff;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.2s, opacity 0.2s;
}

.send-btn:hover:not(:disabled) {
  background: rgba(79, 124, 255, 0.25);
}

.send-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  color: rgba(255, 255, 255, 0.4);
  background: rgba(255, 255, 255, 0.04);
  border-color: rgba(255, 255, 255, 0.1);
}

.error-msg {
  color: #ef4444;
  font-size: 13px;
  margin-top: 8px;
  padding-left: 4px;
}
</style>
