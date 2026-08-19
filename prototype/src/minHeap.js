// Dijkstra用の単純な二分ヒープ（優先度付きキュー）実装。
export default class MinHeap {
  #items = [];

  isEmpty() {
    return this.#items.length === 0;
  }

  push(item, priority) {
    this.#items.push({ item, priority });
    this.#bubbleUp(this.#items.length - 1);
  }

  pop() {
    const top = this.#items[0];
    const last = this.#items.pop();
    if (this.#items.length > 0) {
      this.#items[0] = last;
      this.#bubbleDown(0);
    }
    return top;
  }

  #bubbleUp(index) {
    while (index > 0) {
      const parent = (index - 1) >> 1;
      if (this.#items[parent].priority <= this.#items[index].priority) break;
      [this.#items[parent], this.#items[index]] = [this.#items[index], this.#items[parent]];
      index = parent;
    }
  }

  #bubbleDown(index) {
    const n = this.#items.length;
    while (true) {
      const left = index * 2 + 1;
      const right = index * 2 + 2;
      let smallest = index;
      if (left < n && this.#items[left].priority < this.#items[smallest].priority) smallest = left;
      if (right < n && this.#items[right].priority < this.#items[smallest].priority) smallest = right;
      if (smallest === index) break;
      [this.#items[smallest], this.#items[index]] = [this.#items[index], this.#items[smallest]];
      index = smallest;
    }
  }
}
