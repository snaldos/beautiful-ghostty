# Media assets

- `demo.gif` is the compressed preview embedded in the repository README.
- The full-quality demonstration is hosted as a GitHub user attachment and
  linked from the README.
- `demo-web.mp4` is a local export ignored by Git.

When replacing the preview, keep it short enough for the repository page to load
quickly. One possible conversion is:

```bash
ffmpeg -i assets/demo-web.mp4 \
  -vf "fps=15,scale=1280:-1:flags=lanczos" \
  -loop 0 assets/demo.gif
```
