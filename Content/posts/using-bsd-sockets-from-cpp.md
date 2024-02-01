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

    explicit linked_list_iterator() {}
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

    bool operator==(const linked_list_iterator& other) const {
        return current == other.current;
    }

    bool operator!=(const linked_list_iterator& other) const {
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

## Complete Demo
```C++
#include <cstdlib>
#include <ifaddrs.h>
#include <exception>
#include <string>
#include <netdb.h>
#include <memory>
#include <functional>
#include <algorithm>
#include <iostream>
#include <ranges>
#include <arpa/inet.h>

struct error : public std::exception {
    explicit error(std::string message) : m_message(std::move(message)) {}

    [[nodiscard]] const char * what() const noexcept override {
        return m_message.c_str();
    }

private:
    std::string m_message;
};

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

    explicit linked_list_iterator() {}
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

    linked_list_iterator operator++(int) {
        linked_list_iterator tmp{*this};
        if (current)
            current = next(current);
        return tmp;
    }

    bool operator==(const linked_list_iterator& other) const {
        return current == other.current;
    }

    bool operator!=(const linked_list_iterator& other) const {
        return !(*this == other);
    }

private:
    T *current = nullptr;
};

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

std::vector<std::string> addresses(int family) {
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


    const auto convert = [](ifaddrs& ia) {
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

    auto rng = std::ranges::subrange(begin, end)
    | std::views::filter([family](const auto& ia){ return ia.ifa_addr->sa_family == family; })
    | std::views::transform([convert](auto& ia) { return convert(ia); });

    std::vector<std::string> ips;
    std::transform(rng.begin(), rng.end(), std::back_inserter(ips), std::identity());
    return ips;
}

auto main() -> int {
    std::cout << "ether addresses: " << count_addresses(AF_LINK) << "\n";
    std::cout << "ipv4 addresses: " << count_addresses(AF_INET) << "\n";
    std::cout << "ipv6 addresses: " << count_addresses(AF_INET6) << std::endl;

    for (const auto& address : addresses(AF_INET6))
        std::cout << address << std::endl;

    return EXIT_SUCCESS;
}
```


