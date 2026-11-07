import { Controller } from "@hotwired/stimulus"

// S-4 のサブタスクの入力欄（新規追加）。キャンセルで入力欄のカード（li）ごと閉じる
export default class extends Controller {
  cancel() {
    this.element.remove()
  }
}
