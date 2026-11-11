import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it } from 'vitest'
import { HomePage } from './HomePage'

describe('HomePage', () => {
  it('explains candidate confirmation instead of claiming automatic certainty', () => {
    render(<MemoryRouter><HomePage/></MemoryRouter>)
    expect(screen.getByText(/AI 不是答案/)).toBeInTheDocument()
    expect(screen.getByText(/确认后才记录/)).toBeInTheDocument()
  })
})
