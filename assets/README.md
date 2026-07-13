# Media assets

Replace these placeholder files with your own media while keeping the same
filenames:

- `preview.png` — main repository screenshot, preferably 16:9 or ultrawide.
- `demo.gif` — short looping preview shown directly in the README.
- `demo.mp4` — optional full-quality video linked below the GIF.

Recommended workflow:

1. Record a short clip while changing shader parameters.
2. Save the full clip as `assets/demo.mp4`.
3. Create a shorter GIF named `assets/demo.gif`.
4. Replace `assets/preview.png` with the best frame or a separate screenshot.
5. Uncomment the full-video link in the root `README.md`.

Example GIF conversion with FFmpeg:

```bash
ffmpeg -i assets/demo.mp4 \
  -vf "fps=15,scale=1280:-1:flags=lanczos" \
  -loop 0 assets/demo.gif
```

Keep the GIF short so the repository page loads quickly.
