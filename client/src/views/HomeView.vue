<template>
  <div class="home-view">
    <h1>登录成功</h1>
    <p class="phone">手机号：{{ phone }}</p>
    <button class="logout-btn" @click="logout">退出登录</button>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const phone = ref('')

onMounted(() => {
  const token = localStorage.getItem('token')
  if (!token) {
    router.replace('/')
    return
  }
  phone.value = localStorage.getItem('phone') || '未知'
})

function logout() {
  localStorage.removeItem('token')
  localStorage.removeItem('phone')
  router.replace('/')
}
</script>

<style scoped>
.home-view {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 20px;
}

h1 {
  font-size: 28px;
  background: linear-gradient(135deg, #4f7cff, #a855f7);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.phone {
  color: rgba(255, 255, 255, 0.7);
  font-size: 16px;
}

.logout-btn {
  padding: 10px 32px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 8px;
  color: #fff;
  cursor: pointer;
  transition: background 0.2s;
}

.logout-btn:hover {
  background: rgba(255, 255, 255, 0.2);
}
</style>
