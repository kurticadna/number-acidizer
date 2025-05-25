import { useEffect, useRef } from 'react'
import { useCounterStore } from '../store/counterStore'
import { api } from '../services/api'
import { Button } from './Button'

export const NumberAcidizer = () => {
  const count = useCounterStore((state) => state.count)
  const displayCount = useCounterStore((state) => state.displayCount)
  const isLoading = useCounterStore((state) => state.isLoading)
  const error = useCounterStore((state) => state.error)
  const isInitialized = useCounterStore((state) => state.isInitialized)
  const setCount = useCounterStore((state) => state.setCount)
  const setDisplayCount = useCounterStore((state) => state.setDisplayCount)
  const setLoading = useCounterStore((state) => state.setLoading)
  const setError = useCounterStore((state) => state.setError)
  const setInitialized = useCounterStore((state) => state.setInitialized)

  const animationRef = useRef<number>()

  useEffect(() => {
    if (displayCount !== count) {
      const start = displayCount
      const end = count
      const diff = end - start
      const duration = Math.min(Math.abs(diff) * 100, 2000)
      const startTime = Date.now()

      const animate = () => {
        const elapsed = Date.now() - startTime
        const progress = Math.min(elapsed / duration, 1)

        const easeOutCubic = 1 - Math.pow(1 - progress, 3)
        const current = Math.round(start + diff * easeOutCubic)

        setDisplayCount(current)

        if (progress < 1) {
          animationRef.current = requestAnimationFrame(animate)
        }
      }
      animationRef.current = requestAnimationFrame(animate)
    }
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
    }
  }, [count, displayCount, setDisplayCount])

  useEffect(() => {
    const fetchCount = async () => {
      try {
        setError(null)
        const { count } = await api.getCount()
        setCount(count)
        if (!isInitialized) {
          setDisplayCount(count)
          setInitialized(true)
        }
      } catch (err) {
        setError('Failed to fetch count')
        if (!isInitialized) {
          setInitialized(true)
        }
      }
    }

    fetchCount()
    const interval = setInterval(fetchCount, 7000)
    return () => clearInterval(interval)
  }, [setCount, setDisplayCount, setError, setInitialized, isInitialized])

  const handleAction = async (action: 'increment' | 'decrement') => {
    if (isLoading) return
    setLoading(true)
    setError(null)

    try {
      const { count } = await api.updateCount(action)
      setCount(count)
    } catch (err) {
      setError('Failed to update count')
    } finally {
      setLoading(false)
    }
  }

  if (!isInitialized) {
    return (
      <div className="font-montserrat min-h-screen bg-gray-50 flex flex-col items-center justify-center">
        <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-blue-600 border-t-transparent"></div>
        <p className="mt-6 text-gray-700 text-lg">Loading...</p>
      </div>
    )
  }

  return (
    <div className="font-montserrat min-h-screen bg-gray-50 flex flex-col items-center justify-center">
      <div className="text-8xl mb-8">
        {(displayCount ?? 0).toLocaleString()}
      </div>

      {error && (
        <div className="text-red-600 mb-4">{error}</div>
      )}

      <div className="flex gap-4 mb-4">
        <Button
          onClick={() => handleAction('decrement')}
          disabled={isLoading || count <= 0}
          variant="secondary"
        >
          Decrement
        </Button>

        <Button
          onClick={() => handleAction('increment')}
          disabled={isLoading || count >= 1_000_000_000}
          variant="primary"
        >
          Increment
        </Button>
      </div>
    </div>
  )
}