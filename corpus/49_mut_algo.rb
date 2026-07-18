def bubble_sort(arr)
  n = arr.size
  i = 0
  while i < n
    j = 0
    while j < n - 1
      if arr[j] > arr[j + 1]
        tmp = arr[j]
        arr[j] = arr[j + 1]
        arr[j + 1] = tmp
      end
      j = j + 1
    end
    i = i + 1
  end
  arr
end
puts bubble_sort([5, 2, 8, 1, 9, 3]).join(",")

stack = []
[1, 2, 3].each { |x| stack.push(x) }
result = []
while stack.size > 0
  result << stack.pop
end
puts result.join(",")
