import plugin from 'tailwindcss/plugin';

export default {
  content: [
    './app/views/**/*.{erb,html,rb}',
    './app/javascript/**/*.js',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './engines/*/app/views/**/*.{erb,html,rb}'
  ],
  darkMode: "selector",
  plugins: [
    // Note: @tailwindcss/typography is now imported via @plugin in CSS
    plugin(function({ addUtilities }) {
      addUtilities({
        // Custom utility for color-scheme (not native in Tailwind)
        '.scheme-dark': { 'color-scheme': 'dark' },
        // Note: .outline-hidden and .shadow-xs are now native in Tailwind v4
      })
    }),
  ],
  theme: {
    extend: {
      fontFamily: {
        'sans': ['var(--brand-font-family)', 'system-ui', 'sans-serif'],
      },
      gridTemplateRows: {
        'dashboard': '124px auto auto',
      },
      borderRadius: {
        'none': '0px',
        'sm': '2px',
        'md': '4px',
        'base': '6px',
        'lg': '8px',
        'xl': '12px',
        '2xl': '16px',
        '3xl': '24px',
        'full': '1000px',
      },
      colors: {
        primary: {
          50: '#FFF7ED',
          100: '#FFEDD5',
          200: '#FED7AA',
          300: '#FDB97F',
          400: '#FB9A54',
          500: '#F89D53',
          600: '#EA7C30',
          700: '#C85D1A',
          800: '#9A4510',
          900: '#7C3609',
          DEFAULT: '#F89D53',
          light: '#FFF7ED',
          dark: '#7C3609'
        },
        // Design system colors
        link: '#F89D53',
        backgroundPrimary: '#18181B',
        backgroundSecondary: '#27272A',
        borderPrimary: '#3F3F46',
        textMuted: '#A1A1AA',
        contentPrimary: '#FFFFFF',
        contentSecondary: '#A1A1AA',
        contentTertiary: '#71717A',
        contentInverseSecondary: '#E4E4E7',
        contentInverseTertiary: '#D4D4D8',
        borderInversePrimary: '#3F3F46',
        backgroundInversePrimary: '#52525B',
        actionButton: '#FFFFFF'
      },
      animation: {
        'shine': 'shine 0.5s ease-in-out',
        'slide-in': 'slideIn 0.3s ease-out',
        'fade-out': 'fadeOut 0.3s ease-out 5s forwards',
      },
      keyframes: {
        shine: {
          '0%': { left: '-100%' },
          '100%': { left: '100%' }
        },
        slideIn: {
          'from': {
            opacity: '0',
            transform: 'translateY(-10px)'
          },
          'to': {
            opacity: '1',
            transform: 'translateY(0)'
          }
        },
        fadeOut: {
          'from': {
            opacity: '1',
            transform: 'translateY(0)'
          },
          'to': {
            opacity: '0',
            transform: 'translateY(10px)'
          }
        }
      }
    },
  },
}
