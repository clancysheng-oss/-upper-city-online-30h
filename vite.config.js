import {defineConfig} from 'vite';
export default defineConfig({build:{rollupOptions:{output:{manualChunks(id){
 if(id.includes('node_modules'))return 'vendor';
 if(/\/src\/(novel-|campaign\.js|dialogues\.js)/.test(id))return 'story';
}}}}});
