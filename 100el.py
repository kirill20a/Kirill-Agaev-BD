class SourceClass:

    def __init__(self):
        self.items = [i for i in range(100)]

    def get_items(self):
        return self.items


class TargetClass:

    def __init__(self):
        self.items = []

    def receive_items(self, items):
        
        self.items.extend(items)

    def show_items(self):
        print(f"В целевом классе теперь {len(self.items)} элементов.")
        print(self.items)


def transfer_data(source: SourceClass, target: TargetClass, move=False):

    items_to_transfer = source.get_items()
    target.receive_items(items_to_transfer)

    if move:
        source.items.clear()


if __name__ == "__main__":
    src = SourceClass()
    dst = TargetClass()

    print(f"В источнике {len(src.get_items())} элементов до переноса.")

    # Перенос с удалением из источника (move=True) —
    # если нужно просто скопировать, укажите move=False
    transfer_data(src, dst, move=True)

    print(f"В источнике осталось {len(src.get_items())} элементов после переноса.")
    dst.show_items()