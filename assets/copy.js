document.addEventListener('click', async (e) => {
  const btn = e.target.closest('button.copy');
  if (!btn) return;
  const label = btn.textContent;
  try {
    const res = await fetch(btn.dataset.src);
    await navigator.clipboard.writeText(await res.text());
    btn.textContent = 'copied';
  } catch {
    btn.textContent = 'failed';
  }
  setTimeout(() => (btn.textContent = label), 1500);
});
