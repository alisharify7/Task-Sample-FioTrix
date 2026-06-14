"""
* task management
* author: github.com/alisharify7
* email: alisharifyofficial@gmail.com
* license: see LICENSE for more details.
* Copyright (c) 2026 - ali sharifi
* https://github.com/alisharify7/Task-Sample-FioTrix
"""

import random
import string

SysRandom = random.SystemRandom()


def generate_random_string(length: int = 6, punctuation: bool = True) -> str:
    """generate strong random strings

    :param length: length of random string - default is 6
    :type length: int

    :param punctuation: if this flag is set to `true`, punctuation will be added to random strings
    :type punctuation: bool

     :return: str: random string
    """
    letters = string.ascii_letters
    if punctuation:
        letters += string.punctuation
    random_string = SysRandom.choices(letters, k=length)

    return "".join(random_string)
