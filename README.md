# jekyll-nginx-uwsgi
Docker image combining jekyll, nginx, and uwsgi.

# Building & Running
Add your jekyll site to the app directory.
Keep your nginx.conf and uwsgi.ini in the same directory as the Dockerfile then run:
```
docker build -t jekyll-nginx-uwsgi .
```

Run an instance of the image using:
```
docker run -p 80:80 jekyll-nginx-uwsgi
```

# Example Usage
An example project is available at [plain-web-utils](https://github.com/Meptl/plain-web-utils).
