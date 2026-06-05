<template>
  <div class="phone-input-wrapper">
    <div class="input-row">
      <div class="area-code" @click="toggleDropdown">
        <span>{{ selectedAreaCode }}</span>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M3 4.5L6 7.5L9 4.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
        <div v-if="showDropdown" class="dropdown">
          <div
            v-for="area in areaCodes"
            :key="area.code"
            class="dropdown-item"
            :class="{ active: area.code === selectedAreaCode }"
            @click.stop="selectAreaCode(area.code)"
          >
            {{ area.flag }} {{ area.code }}
          </div>
        </div>
      </div>
      <input
        type="tel"
        :value="modelValue"
        placeholder="请输入手机号"
        maxlength="11"
        @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value.replace(/\D/g, ''))"
        @blur="$emit('blur')"
      />
    </div>
    <p v-if="error" class="error-msg">{{ error }}</p>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  modelValue: string
  areaCode: string
  error?: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'update:areaCode': [value: string]
  blur: []
}>()

const showDropdown = ref(false)

const areaCodes = [
  { code: '+86', flag: '🇨🇳' },
  { code: '+852', flag: '🇭🇰' },
  { code: '+886', flag: '🇹🇼' },
  { code: '+1', flag: '🇺🇸' },
]

const selectedAreaCode = ref(props.areaCode || '+86')

function toggleDropdown() {
  showDropdown.value = !showDropdown.value
}

function selectAreaCode(code: string) {
  selectedAreaCode.value = code
  emit('update:areaCode', code)
  showDropdown.value = false
}
</script>

<style scoped>
.phone-input-wrapper {
  width: 100%;
}

.input-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.area-code {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 14px 12px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: rgba(255, 255, 255, 0.8);
  font-size: 14px;
  cursor: pointer;
  position: relative;
  user-select: none;
  transition: border-color 0.2s;
  white-space: nowrap;
}

.area-code:hover {
  border-color: rgba(255, 255, 255, 0.2);
}

.dropdown {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  min-width: 120px;
  background: rgba(20, 20, 30, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  padding: 6px;
  z-index: 10;
}

.dropdown-item {
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  transition: background 0.15s;
}

.dropdown-item:hover {
  background: rgba(255, 255, 255, 0.08);
}

.dropdown-item.active {
  background: rgba(79, 124, 255, 0.2);
}

input {
  flex: 1;
  padding: 14px 16px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: #fff;
  font-size: 15px;
  outline: none;
  transition: border-color 0.2s;
}

input::placeholder {
  color: rgba(255, 255, 255, 0.3);
}

input:focus {
  border-image: linear-gradient(135deg, #4f7cff, #a855f7) 1;
}

.error-msg {
  color: #ef4444;
  font-size: 13px;
  margin-top: 8px;
  padding-left: 4px;
}
</style>
