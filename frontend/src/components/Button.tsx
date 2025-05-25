interface ButtonProps {
    children: React.ReactNode
    onClick: () => void
    disabled?: boolean
    variant?: 'primary' | 'secondary'
  }

  export const Button = ({ children, onClick, disabled = false, variant = 'primary' }: ButtonProps) => {
    const baseClasses = "px-6 py-2 disabled:opacity-50 disabled:cursor-not-allowed rounded-sm shadow-sm hover:shadow-md-500/10"
    const variantClasses = variant === 'primary'
      ? "bg-blue-800 text-white hover:bg-blue-800"
      : "bg-gray-200 hover:bg-gray-300"

    return (
      <button
        onClick={onClick}
        disabled={disabled}
        className={`${baseClasses} ${variantClasses}`}
      >
        {children}
      </button>
    )
  }