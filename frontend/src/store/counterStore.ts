import { create } from 'zustand'

interface CounterStore {
  count: number
  displayCount: number
  isLoading: boolean
  error: string | null

  setCount: (count: number) => void
  setDisplayCount: (count: number) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
}

export const useCounterStore = create<CounterStore>((set, get) => ({
  count: 0,
  displayCount: 0,
  isLoading: false,
  error: null,

  setCount: (count: number) => set({ count }),
  setDisplayCount: (displayCount: number) => set({ displayCount }),
  setLoading: (isLoading: boolean) => set({ isLoading }),
  setError: (error: string | null) => set({ error }),
}))