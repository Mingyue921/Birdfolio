import { expect, test } from '@playwright/test'

test('competition demo exposes the identification workflow', async ({ page }) => {
  await page.goto('/identify')
  await expect(page.getByRole('heading', { name: /可信观察/ })).toBeVisible()
  await expect(page.getByRole('button', { name: /选择鸟类照片/ })).toBeVisible()
  await expect(page.getByText(/确认之前.*不会创建观察记录/)).toBeVisible()
})
