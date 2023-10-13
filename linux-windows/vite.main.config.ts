import { defineConfig } from 'vite';
import * as path from 'path';

export default defineConfig({
  build: {
    rollupOptions: {
      // Override the output directory
      output: {
        dir: path.resolve(__dirname, 'dist')
      }
    }
  },
  resolve: {
    browserField: false,
    mainFields: ['module', 'jsnext:main', 'jsnext'],
    alias: {
    }
  },
  esbuild: {
    platform: 'node',
    loader: 'ts'
  }
});
