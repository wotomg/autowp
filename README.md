# autowp
Script for automated WordPress installation.
I don't use it anymore. But probably it's still working.
Or maybe someone intrested.

## Usage
1. Run init.sh for init new Apache2/MySQL webserver.
2. Run autowp.sh to create and autoconfigure new WordPress site.

```
Example: autowp.sh -d example.com -e user@example.com
or: autowp.sh -w -f -d example.com -e user@example.com
-d -- domain name
-e -- administrator email
-f -- ignore domain and email check
-w -- create www.domain.ltd alias
```
