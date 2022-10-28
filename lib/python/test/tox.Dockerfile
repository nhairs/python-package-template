FROM python:3.11

# This stuff
WORKDIR /srv

RUN mkdir /srv/dist /srv/tests

RUN pip install tox

# https://tox.readthedocs.io/en/latest/example/pytest.html
CMD tox
