FROM     ubuntu:14.04.1

# ---------------- #
#   Installation   #
# ---------------- #

# Install all prerequisites
RUN     apt-get -y install software-properties-common
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     apt-get -y update
RUN     apt-get -y install python-django-tagging python-simplejson python-memcache python-ldap python-cairo python-pysqlite2 python-support \
                           python-pip gunicorn supervisor nginx-light nodejs git wget curl openjdk-7-jre build-essential python-dev

RUN     pip install Twisted==11.1.0
RUN     pip install Django==1.5


# Install Elasticsearch
#RUN     cd ~ && wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.2.deb
#RUN     cd ~ && dpkg -i elasticsearch-1.3.2.deb && rm elasticsearch-1.3.2.deb

# Checkout the stable branches of Graphite, Carbon and Whisper and install from there
RUN     mkdir /src
RUN     git clone https://github.com/graphite-project/whisper.git /src/whisper            &&\
        cd /src/whisper                                                                   &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install

RUN     git clone https://github.com/graphite-project/carbon.git /src/carbon              &&\
        cd /src/carbon                                                                    &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install


RUN     git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web  &&\
        cd /src/graphite-web                                                              &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install

# Install StatsD
RUN     git clone https://github.com/etsy/statsd.git /src/statsd                                                                        &&\
        cd /src/statsd                                                                                                                  &&\
        git checkout v0.7.2


# Install Grafana
ENV     GRAFANA_VERSION 2.0.2
RUN     mkdir -p /var/lib/grafana
RUN     mkdir -p /var/log/grafana
RUN     chown -R www-data /var/lib/grafana && chown -R www-data /var/log/grafana
RUN     wget http://grafanarel.s3.amazonaws.com/builds/grafana-${GRAFANA_VERSION}.linux-x64.tar.gz -O - | tar -xzv -C /src
RUN     mv /src/grafana-${GRAFANA_VERSION} /src/grafana
ADD     ./grafana/grafana.ini /src/grafana/grafana.ini


# ----------------- #
#   Configuration   #
# ----------------- #

# Configure Elasticsearch
#ADD     ./elasticsearch/run /usr/local/bin/run_elasticsearch
#RUN     chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
#RUN     mkdir -p /tmp/elasticsearch && chown elasticsearch:elasticsearch /tmp/elasticsearch

# Confiure StatsD
ADD     ./statsd/config.js /src/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/initial_data.json /opt/graphite/webapp/graphite/initial_data.json
ADD     ./graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
RUN     mkdir -p /opt/graphite/storage/whisper
RUN     touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index
RUN     chown -R www-data /opt/graphite/storage
RUN     chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper
RUN     chmod 0664 /opt/graphite/storage/graphite.db
RUN     cd /opt/graphite/webapp/graphite && python manage.py syncdb --noinput

# Configure Grafana
#ADD     ./grafana/config.js /src/grafana/config.js

# Add the default dashboards
#RUN     mkdir /src/dashboards
#ADD     ./grafana/dashboards/* /src/dashboards/

# Configure nginx and supervisord
ADD     ./nginx/nginx.conf /etc/nginx/nginx.conf
ADD     ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  3000 2000 2003

# StatsD UDP port
#EXPOSE  8125/udp

# StatsD Management port
#EXPOSE  8126



# -------- #
#   Run!   #
# -------- #

CMD     ["/usr/bin/supervisord"]

# Set http://127.0.0.1/graphite (proxy) as datasource in the grafana menu
# http://docs.grafana.org/v2.0/installation/migrating_to2/
