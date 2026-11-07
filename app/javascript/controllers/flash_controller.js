import { Controller } from "@hotwired/stimulus"

// お知らせ（flash）。閉じるボタン（flash#close）で消す。
// timeout（ミリ秒）が正のときは、その時間で自動的に消す（値が変わったら数え直す）
export default class extends Controller {
  static values = { timeout: Number }

  disconnect() {
    clearTimeout(this.timer)
  }

  timeoutValueChanged() {
    clearTimeout(this.timer)
    if (this.timeoutValue > 0) this.timer = setTimeout(() => this.close(), this.timeoutValue)
  }

  close() {
    this.element.remove()
  }
}
