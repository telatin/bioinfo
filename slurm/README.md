# Slurm wrapper

This is a simple wrapper for sending jobs to SLURM at QI.

### Installation

Place this directory in your home, adding it to the path.

The first time that *sb.pl* is run, it will attempt creating two subdirectories:
 - **~/slurm/jobs**: to store jobs scripts
 - **~/slurm/logs**: to store logs, STDERR and STDOUT

Add ~/slurm to your $PATH to ensure the ability to invoke 'sb.pl' from anywhere.

#### Optional files

If you use Miniconda create a file called ~/conda_source with the Miniconda installation path, like:
```
export PATH=/home/yourname/Minicondaconda3/bin:$PATH
```

If you want to store your e-mail address as default recipient, simply type the e-mail address in a file called `~/.slurm_default_mail`

### Usage
[Andrea Telatin](https://quadram.ac.uk/people/andrea-telatin/)

