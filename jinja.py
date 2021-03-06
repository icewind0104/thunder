import os, sys, time
from jinja2 import Environment, FileSystemLoader

dirname, filename = os.path.split(os.path.abspath(__file__))
env = Environment(loader=FileSystemLoader(dirname))
template = env.get_template('src/' + sys.argv[1] + '.sh')
print(template.render(date=time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())))
