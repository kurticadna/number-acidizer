import { BackendResponse, CountResponse, ApiError } from '../types/api'

function getApiUrl(): string {
    const url = process.env.NEXT_PUBLIC_API_URL
    if (!url) {
      throw new ApiError(500, 'API URL not configured. Please contact support.')
    }
    return url
  }


const defaultHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json'
}

const fetchWithDefaults = (url: string, options?: RequestInit): Promise<Response> => {
  return fetch(url, {
    ...options,
    headers: { ...defaultHeaders, ...options?.headers }
  })
}

const handleApiResponse = async (response: Response): Promise<BackendResponse> => {
  if (!response.ok) {
    throw new ApiError(response.status, `HTTP ${response.status}: ${response.statusText}`)
  }

  try {
    const data: BackendResponse = await response.json()
    if (!data.success) {
      throw new ApiError(400, data.error || 'Unknown error from server')
    }

    return data
  } catch (error) {
    if (error instanceof ApiError) throw error
    throw new ApiError(500, 'Failed to parse server response')
  }
}

export const api = {
  async getCount(): Promise<CountResponse> {
    try {
      const API_URL = getApiUrl()
      const response = await fetchWithDefaults(API_URL)
      const data = await handleApiResponse(response)
      return { count: data.value || 0 }
    } catch (error) {
      if (error instanceof ApiError) throw error
      throw new ApiError(500, 'Network error while fetching count')
    }
  },

  async updateCount(action: 'increment' | 'decrement'): Promise<CountResponse> {
    try {
      const API_URL = getApiUrl()
      const response = await fetchWithDefaults(API_URL, {
        method: 'POST',
        body: JSON.stringify({ action })
      })

      const data = await handleApiResponse(response)
      return { count: data.value || 0 }
    } catch (error) {
      if (error instanceof ApiError) throw error
      throw new ApiError(500, 'Network error while updating count')
    }
  }
}