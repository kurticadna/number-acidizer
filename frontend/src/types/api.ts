
export interface BackendResponse {
    success: boolean
    value?: number
    error?: string
  }

  export interface CountResponse {
    count: number
  }

  export class ApiError extends Error {
    constructor(public status: number, message: string) {
      super(message)
      this.name = 'ApiError'
    }
  }