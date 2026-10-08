FROM nginx:alpine
<<<<<<< HEAD
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/
EXPOSE 3000
=======

COPY dist/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

>>>>>>> 0352910106950e8257be642c6d92f0ec1e9b5a6c
CMD ["nginx", "-g", "daemon off;"]

