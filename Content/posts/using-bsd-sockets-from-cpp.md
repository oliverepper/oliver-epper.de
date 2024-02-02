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

This is not a good solution, because it's hard to make sure that the free-function is called and called only once. In C++ smart-pointers provide a handle to a memory allocation and thus can guarantee the release of the resource.

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
#include <cstddef>
#include <iterator>
#include <functional>

template <typename T>
struct linked_list_iterator {
    using value_type        = T;
    using difference_type   = std::ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using pointer           = T*;
    using refernce          = T&;
    using Next              = std::function<T*(T*)>;

    explicit linked_list_iterator(T* current, Next next) : m_current{current}, m_next{next} {}

    refernce operator*() const {
        return *m_current;
    }

    pointer operator->() const {
        return &(operator*());
    }

    linked_list_iterator operator++() {
        if (m_current)
            m_current = m_next(m_current);
        return *this;
    }

    linked_list_iterator operator++(int) {
        linked_list_iterator temp{*this};
        if (m_current)
            m_current = m_next(m_current);
        return temp;
    }

    bool operator==(const linked_list_iterator& other) const {
        return m_current == other.m_current;
    }

    bool operator!=(const linked_list_iterator& other) const {
        return !(*this == other);
    }

private:
    Next m_next;
    T *m_current = nullptr;
};
```

### Using count_if example

```C++
int count_addresses(int family) {
    auto deleter = [](ifaddrs *ia) { freeifaddrs(ia); };
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
    auto end = linked_list_iterator<ifaddrs>{};

    return std::count_if(begin, end, [family](auto &ia) { return ia.ifa_addr->sa_family == family; });
}
```

## Complete Demo

[Chris Tietze](https://christiantietze.de) made me realize that wrapping things up in a handle class `IfAddrs` makes things even nicer!

### IfAddrs
```C++
#include "linked_list_iterator.h"
#include <ifaddrs.h>
#include <netdb.h>

struct IfAddrs {
    static constexpr auto deleter = [](ifaddrs *ia){ freeifaddrs(ia); };

    explicit IfAddrs() : m_list{nullptr} {
        ifaddrs *list;
        int status;
        if ((status = getifaddrs(&list)) != 0)
            throw std::runtime_error{gai_strerror(status)};

        m_list.reset(list);
    }

    linked_list_iterator<ifaddrs> begin() {
        return linked_list_iterator<ifaddrs>(m_list.get(), [](ifaddrs *ia){ return ia->ifa_next; });
    }

    linked_list_iterator<ifaddrs> end() {
        return linked_list_iterator<ifaddrs>(nullptr, nullptr);
    }

private:
    std::unique_ptr<ifaddrs, decltype(deleter)> m_list;
};

```

### main
```C++
auto main() -> int {
    const auto convert = [](ifaddrs &ia) {
        switch (ia.ifa_addr->sa_family) {
            case AF_INET: {
                auto address = reinterpret_cast<sockaddr_in *>(ia.ifa_addr);
                char ip[INET_ADDRSTRLEN];
                inet_ntop(AF_INET, &(address->sin_addr), ip, INET_ADDRSTRLEN);
                return std::string{ip};
            }
            case AF_INET6: {
                auto address = reinterpret_cast<sockaddr_in6 *>(ia.ifa_addr);
                char ip[INET6_ADDRSTRLEN];
                inet_ntop(AF_INET6, &(address->sin6_addr), ip, INET6_ADDRSTRLEN);
                return std::string{ip};
            }
            default: {
                return std::string{"Unknown"};
            }
        }
    };

    auto ips = std::views::all(IfAddrs{})
               | std::views::filter([](const auto& ia){ return ia.ifa_addr->sa_family == AF_INET6; })
               | std::views::transform([&convert](auto& ia){ return convert(ia); });

    for (const auto& ip : ips)
        std::cout << ip << std::endl;

    return EXIT_SUCCESS;
}
```
