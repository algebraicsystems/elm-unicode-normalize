# elm-unicode-normalize

This package provides a pure Elm implementation of the [Unicode Normalization](https://www.unicode.org/reports/tr15/) algorithm.

## Isn't that already available via `String.prototype.normalize()`?

**Yes, and you should probably use that instead!** This implementation certainly will be slower than the browser's well-optimized solution.

I created this package because I needed to normalize strings deep inside some complicated business logic. Calling out to the JavaScript implementation through a port was possible, but really not ideal. I would have to turn my business logic into a `port module`, add messages interrupting the normal control flow, a lot of the code couldn't be pure Elm anymore, et cetera, et cetera, et cetera. If you find yourself in a similar situation, this package is for you!

## How do I know this works correctly?

The test suite is generated from [the suite provided by Unicode](https://www.unicode.org/reports/tr44/#NormalizationTest_txt). There are quite a lot of tests, so it takes a while to run, but I am highly confident that the implementation is correct. Try `make test` to run the tests for yourself.

## Planned performance improvements

The current version of this package is a very naive implementation focusing entirely on correctness over performance. The code operates directly on a list of code points (`List Int` internally). However, it is definitely possible to do better, even in pure Elm! Here are some planned improvements:

1. Don't break down the string into code points if it is already normalized.
2. Process sections that need to be normalized in small chunks instead of processing the whole string all at once.
3. Use a more efficient intermediate representation like an `Array Int`.
