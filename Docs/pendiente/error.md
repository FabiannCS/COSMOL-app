 7 |

   8 | >>> RUN apt-get update && apt-get install -y --no-install-recommends \

   9 | >>>     curl \

  10 | >>>     gcc \

  11 | >>>     libpq-dev \

  12 | >>>     && rm -rf /var/lib/apt/lists/*

  13 |

--------------------

failed to solve: process "/bin/sh -c apt-get update && apt-get install -y --no-install-recommends     curl     gcc     libpq-dev     && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100



View build details: docker-desktop://dashboard/build/default/default/p58rotmulw1h54tkl0jnnsvq7


What's next:
    Debug this Compose error with Gordon → docker ai "help me fix this compose error"
PS C:\Users\Lenovo\Desktop\COSMOL-app> 