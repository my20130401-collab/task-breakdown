import { Controller } from "@hotwired/stimulus"

// モック：「タスクを追加」でカードを末尾に追加し（保存はしない）、親タスクの進捗をサブタスクの完了数に合わせる。
// 追加したカードはタスク名の入力欄へフォーカスし、subtasks:added イベントを出す（日付タブはこれを受けて「すべて」に戻す）。
// 進捗のマークアップは shared/_task_progress と同じ規則で書き換える
export default class extends Controller {
  static targets = ["list", "template", "progress"]

  connect() {
    if (!this.hasListTarget) return

    this.renderProgress()
    this.observer = new MutationObserver(() => this.renderProgress())
    this.observer.observe(this.listTarget, { subtree: true, childList: true, attributes: true, attributeFilter: ["data-done"] })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  // 番号は完了状態に関わらず追加順。id（メニューなど）にも番号を使うため、テンプレート内の __NUMBER__ はすべて置き換える
  add() {
    const number = String(this.listTarget.children.length + 1).padStart(2, "0")
    const html = this.templateTarget.innerHTML.replaceAll("__NUMBER__", number)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    const card = this.listTarget.lastElementChild
    this.dispatch("added", { detail: { card } })
    card.querySelector("[contenteditable='true']")?.focus()
  }

  renderProgress() {
    if (!this.hasProgressTarget || !this.hasListTarget) return

    const cards = Array.from(this.listTarget.querySelectorAll(":scope > [data-done]"))
    const total = cards.length
    const done = cards.filter((card) => card.dataset.done === "true").length
    const root = this.progressTarget.querySelector("[data-task-progress]")
    const text = root.querySelector("[data-task-progress-text]")
    const label = total > 0 ? `${done}/${total} 完了` : "—"
    // 同じ値の書き換えで observer を空回りさせない（監視対象は一覧だけなので無限ループはしないが、無駄な再描画を避ける）
    if (text.textContent === label) return

    text.textContent = label
    text.classList.toggle("text-muted", total > 0)
    text.classList.toggle("text-subtle", total === 0)
    root.querySelector("[data-task-progress-track]").hidden = total === 0
    // バー幅は _task_progress と同じく 100% を上限にする
    root.querySelector("[data-task-progress-bar]").style.width = `${total > 0 ? Math.min(100, Math.floor((done * 100) / total)) : 0}%`
    if (total > 0) {
      root.setAttribute("role", "progressbar")
      root.setAttribute("aria-label", "進捗")
      root.setAttribute("aria-valuemin", "0")
      root.setAttribute("aria-valuenow", String(done))
      root.setAttribute("aria-valuemax", String(total))
    } else {
      for (const name of ["role", "aria-label", "aria-valuemin", "aria-valuenow", "aria-valuemax"]) root.removeAttribute(name)
    }
  }
}
