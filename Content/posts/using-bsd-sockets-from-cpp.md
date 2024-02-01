---
date: 2024-02-01 9:42
title: Using the BSD socket API from C++
description: How I use the BSD socket API from C++
tags: network, BSD, sockets, cpp 
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Setting the stage
A lot of the POSIX API functions come in pairs: `getifaddrs` and `freeifaddrs` or `getaddrinfo` and `freeaddrinfo`. Both take the address of a pointer as an out parameter and, if successful, make that point to a linked-list allocated on the free-store. This memory resources must be freed via the `free`-functions.

```C++
void demo() {
    ifaddrs *result;
    int status{0};
    if ((status = getifaddrs(&result)) != 0)
        throw error{gai_strerror(status)};

    // use result

    freeifaddrs(result);
}
```

This is not a good solution, because it's hard to make sure that the free-function is called and called only once. In C++ smart-pointer provides a handle to a memory allocation and thus can guarantee the release of the resource.

## Using a smart-pointer for the out parameter

```C++
void demo() {
    auto deleter = [](ifaddrs *ia){ freeifaddrs(ia); };
    std::unique_ptr<ifaddrs, decltype(deleter)> result;

    {
        ifaddrs *temp;
        int status{0};
        if ((status = getifaddrs(&temp)) != 0)
            throw error{gai_strerror(status)};
        result.reset(temp);
    }

    // use result
}
```

This is really nice. The smart-pointer handles the release of the allocated memory for us, now.

## Using C++ algorithms

Since these POSIX functions provide linked-lists it would be very nice to provide an iterator that would make them usable with the STL algorithms.

### Linked-List-Iterator

```C++
template <typename T>
class linked_list_iterator {
public:
    using value_type = T;
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;

    using pointer = value_type*;
    using reference = value_type&;

    using Next = std::function<T*(T*)>;
    Next next = [](T*){ return nullptr; };

    explicit linked_list_iterator(T *ptr, Next next) : current{ptr}, next{std::move(next)} {}

    reference operator*() const {
        return *current;
    }

    pointer operator->() const {
        return &**this;
    }

    linked_list_iterator& operator++() {
        if (current)
            current = next(current);
        return *this;
    }

    bool operator==(const linked_list_iterator& other) {
        return current == other.current;
    }

    bool operator!=(const linked_list_iterator& other) {
        return !(*this == other);
    }

private:
    T *current = nullptr;
};

```

### Using count_if example

```C++
int count_addresses(int family) {
    auto deleter = [](ifaddrs *ia){ freeifaddrs(ia); };
    std::unique_ptr<ifaddrs, decltype(deleter)> result;

    {
        ifaddrs *temp;
        int status{0};
        if ((status = getifaddrs(&temp)) != 0)
            throw error{gai_strerror(status)};
        result.reset(temp);
    }

    // use result
    auto begin = linked_list_iterator<ifaddrs>(result.get(), [](ifaddrs *ia) { return ia->ifa_next; });
    auto end = linked_list_iterator<ifaddrs>(nullptr, begin.next);

    return std::count_if(begin, end, [family](auto& ia){ return ia.ifa_addr->sa_family == family; });
}
```


