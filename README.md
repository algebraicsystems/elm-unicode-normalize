# elm-unicode-normalize

This package provides a pure Elm implementation of the [Unicode Normalization](https://www.unicode.org/reports/tr15/) algorithm.

## Isn't that already available via `String.prototype.normalize()`?

**Yes, and you should probably use that instead!** This implementation certainly will be slower than the browser's well-optimized solution.

I created this package because I needed to normalize strings deep inside some complicated business logic. Calling out to the JavaScript implementation through a port was possible, but really not ideal. I would have to turn my business logic into a `port module`, add messages interrupting the normal control flow, a lot of the code couldn't be pure Elm anymore, et cetera, et cetera, et cetera. If you find yourself in a similar situation, this package is for you!
