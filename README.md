# Docker Image for TOE

Dockerfile for TOE.

 * Based on Debian 7
 * Mapnik 2.0.0
 * OpenStreetMap data for Isle of Man

### Running

```bash
$ sudo docker run -p 8000:80 iqqmut/toe
```

Open your browser: http://localhost:8000/

TOE is installed to `/opt/toe`

Image is bundled with OpenStreetMap data from Isle of Man because of its small size. Therefore PDF printing works correctly only at Isle of Man.
