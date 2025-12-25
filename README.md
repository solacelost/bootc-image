# bootc-image

This is the code to build the [bootc](https://bootc-dev.github.io/bootc/)-based [Fedora Remix](https://fedoraproject.org/wiki/Remix)
I use the image on multiple computers. It's just on my main desktop and a couple of laptops at the moment,
but I'd like to move to a custom image instead of [Bazzite](https://bazzite.gg/) on my TV PC.
There's a couple of really bad reasons for this (I am a control freak and a technology nerd and I like having deeply customized setups),
but also a couple of really good reasons (I work with bootc-based technology as my day job and keeping myself engaged in it keeps me sharp).

Using bootc in particular allows me to ensure I have a consistent experience on every machine, without a dotfiles repo,
and without configuration drift (or, at least with recoverable configuration drift).

## Can I use this?

Sure! The image is currently published at quay.io/solacelost/bootc-image:latest.
You're welcome to use it directly, or else you can steal snippets of my code that are useful to you.
If you don't know how to use the image directly, probably just "borrow" the useful code.

### TODO

- [ ] Implement a decent Shikane setup
- [ ] Investigate RaySession?
- [ ] Enable fprintd to detect fingerprint reader and prompt to set if unset
- [ ] Find a better public CI / build system than GHA
- [ ] Implement multiple image builds from the composable pieces (focusing on a SteamOS-style full screen setup without a desktop)
