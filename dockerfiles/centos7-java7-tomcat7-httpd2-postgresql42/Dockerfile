FROM centos:7

ENV CATALINA_HOME=/usr/local/tomcat
ENV PATH=$CATALINA_HOME/bin:$PATH

WORKDIR /root

ARG TARGETARCH

RUN if [ "$TARGETARCH" = "arm64" ] || [ "$TARGETARCH" = "arm" ]; then \
    printf '%s\n' \
      "[base]" \
      "name=CentOS-7 - Base" \
      'baseurl=http://vault.centos.org/altarch/7.9.2009/os/$basearch/' \
      "gpgcheck=0" \
      "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" \
      "" \
      "[updates]" \
      "name=CentOS-7 - Updates" \
      'baseurl=http://vault.centos.org/altarch/7.9.2009/updates/$basearch/' \
      "gpgcheck=0" \
      "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" \
      "" \
      "[extras]" \
      "name=CentOS-7 - Extras" \
      'baseurl=http://vault.centos.org/altarch/7.9.2009/extras/$basearch/' \
      "gpgcheck=0" \
      "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" \
      > /etc/yum.repos.d/CentOS-Base.repo; \
  else \
    printf '%s\n' \
      "[base]" \
      "name=CentOS-7 - Base" \
      'baseurl=http://vault.centos.org/7.9.2009/os/$basearch/' \
      "gpgcheck=0" \
      "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" \
      "" \
      "[updates]" \
      "name=CentOS-7 - Updates" \
      'baseurl=http://vault.centos.org/7.9.2009/updates/$basearch/' \
      "gpgcheck=0" \
      "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" \
      "" \
      "[extras]" \
      "name=CentOS-7 - Extras" \
      'baseurl=http://vault.centos.org/7.9.2009/extras/$basearch/' \
      "gpgcheck=0" \
      "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" \
      > /etc/yum.repos.d/CentOS-Base.repo; \
  fi

RUN yum -y update && \
    yum -y install curl java-1.7.0-openjdk-devel && \
    yum -y install epel-release && \
    yum -y install supervisor && \
    yum clean all

# Descarga y extrae Tomcat standalone
RUN curl -fSL https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.109/bin/apache-tomcat-7.0.109.tar.gz -o /tmp/tomcat.tar.gz && \
    mkdir -p $CATALINA_HOME && \
    tar -xzf /tmp/tomcat.tar.gz -C $CATALINA_HOME --strip-components=1 && \
    rm /tmp/tomcat.tar.gz

# Corrige permisos (opcional si no se usan usuarios)
RUN chmod +x $CATALINA_HOME/bin/*.sh

# Expone el puerto
EXPOSE 80

# Añadir librería de Postgres
COPY postgresql-42.2.28.jre7.jar $CATALINA_HOME/lib/postgresql-42.2.28.jre7.jar

# Añadir server.xml modificado
COPY server-debian8.xml $CATALINA_HOME/conf/server.xml

# Elimina todo el contenido por defecto de WebApps
RUN rm -rf $CATALINA_HOME/webapps/*

# Copia el WAR a webapps
COPY sample.war $CATALINA_HOME/webapps/ROOT.war

# Reemplazar puerto 8080 por 80
RUN sed -i 's/8080/80/g' $CATALINA_HOME/conf/server.xml

# Copiar fichero de configuración de supervisor
COPY services.conf /etc/supervisord.d/services.ini

# # Instalar httpd
# RUN yum -y install httpd

# # Copiar configuración
# COPY httpd.conf /etc/httpd/conf/httpd.conf

# Ejecuta procesos en segundo plano
CMD ["supervisord", "-n"]
