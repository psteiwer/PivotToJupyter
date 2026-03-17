ARG IMAGE=intersystemsdc/iris-community
FROM $IMAGE

USER root
WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp

USER ${ISC_PACKAGE_MGRUSER}

# copy files
COPY src src
COPY iris.script /tmp/iris.script
COPY module.xml module.xml

# run iris and script
RUN iris start IRIS \
	&& iris session IRIS < /tmp/iris.script \
    && iris stop IRIS quietly

RUN mkdir -p /usr/irissys/mgr/user/notebooks
RUN python3 -m pip install notebook pandas matplotlib seaborn sqlalchemy-intersystems-iris

COPY --chmod=+x entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set the default command to run Jupyter Notebook
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--ServerApp.root_dir=/usr/irissys/mgr/user/notebooks", "--MappingKernelManager.cull_idle_timeout=120", "--MappingKernelManager.cull_interval=60", "--MappingKernelManager.cull_connected=True"]