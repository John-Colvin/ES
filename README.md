ES
==

new_algo branch:
implements some new more flexible internals, including a change from parents being integer indexes to being class references

A simple evolutionary strategies package for D.

This is a work in progress and might completely change overnight. Be warned.
At this early stage, I offer no promises that this should compile at any given time, let alone run without errors and provide any useful results.
There are a lot of hacks in the code at the moment. These will be phased out in time when I get around to it.

Prerequisites:
A D2 compiler with phobos and druntime. I'm currently using the latest dmd from github and that's the only compiler i'm attempting to maintain compatability with at this time. Having said that, it should work with anything vaguely up-to-date.

D-Yaml - for the config files. https://github.com/kiith-sa/D-YAML

Orange - for some aggregate introspection. https://github.com/jacob-carlborg/orange


note on Orange:

All that's needed at the moment is the template nameOfFieldAt from orange.util.reflection

If you don't want to install the whole of orange, just copy that template in at the end of ES.JCutils.d instead.
