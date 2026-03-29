module.exports = {
  content: ["./**/*.html"],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: 'hsl(84, 75%, 55%)', dark: 'hsl(84, 75%, 45%)', light: 'hsl(84, 20%, 92%)' },
        surface: { DEFAULT: 'hsl(40, 15%, 98%)', muted: 'hsl(40, 6%, 93%)' },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
    },
  },
}
