FROM rocker/r-ver:4.1.0
RUN apt-get update && apt-get install -y  git-core libcurl4-openssl-dev libgit2-dev libglpk-dev libgmp-dev libicu-dev libssl-dev libxml2-dev make pandoc pandoc-citeproc zlib1g-dev libglpk40 && rm -rf /var/lib/apt/lists/*
RUN echo "options(repos = 'https://mirrors.dotsrc.org/cran/', download.file.method = 'libcurl', Ncpus = 4)" >> /usr/local/lib/R/etc/Rprofile.site
RUN R -e 'install.packages("remotes")'
RUN Rscript -e 'remotes::install_version("magrittr",upgrade="never", version = "2.0.1")'
RUN Rscript -e 'remotes::install_version("glue",upgrade="never", version = "1.4.2")'
RUN Rscript -e 'remotes::install_version("markdown",upgrade="never", version = "1.1")'
RUN Rscript -e 'remotes::install_version("data.table",upgrade="never", version = "1.14.0")'
RUN Rscript -e 'remotes::install_version("htmltools",upgrade="never", version = "0.5.1.1")'
RUN Rscript -e 'remotes::install_version("knitr",upgrade="never", version = "1.33")'
RUN Rscript -e 'remotes::install_version("pkgload",upgrade="never", version = "1.2.1")'
RUN Rscript -e 'remotes::install_version("attempt",upgrade="never", version = "0.3.1")'
RUN Rscript -e 'remotes::install_version("testthat",upgrade="never", version = "3.0.4")'
RUN Rscript -e 'remotes::install_version("lubridate",upgrade="never", version = "1.7.10")'
RUN Rscript -e 'remotes::install_version("shiny",upgrade="never", version = "1.6.0")'
RUN Rscript -e 'remotes::install_version("config",upgrade="never", version = "0.3.1")'
RUN Rscript -e 'remotes::install_version("styler",upgrade="never", version = "1.5.1")'
RUN Rscript -e 'remotes::install_version("spelling",upgrade="never", version = "NA")'
RUN Rscript -e 'remotes::install_version("rmarkdown",upgrade="never", version = "2.10")'
RUN Rscript -e 'remotes::install_version("devtools",upgrade="never", version = "2.4.2")'
RUN Rscript -e 'remotes::install_version("highcharter",upgrade="never", version = "0.8.2")'
RUN Rscript -e 'remotes::install_version("shinyMobile",upgrade="never", version = "0.9.0")'
RUN Rscript -e 'remotes::install_version("rdrop2",upgrade="never", version = "0.8.2.1")'
RUN Rscript -e 'remotes::install_version("plyr",upgrade="never", version = "1.8.6")'
RUN Rscript -e 'remotes::install_version("golem",upgrade="never", version = "0.3.1")'
RUN Rscript -e 'remotes::install_version("DT",upgrade="never", version = "0.18")'
RUN Rscript -e 'remotes::install_github("RinteRface/charpente@2fc59f23f7449f7f6a6464ed100055cfdba6a374")'
RUN mkdir /build_zone
ADD . /build_zone
WORKDIR /build_zone
RUN R -e 'remotes::install_local(upgrade="never")'
RUN rm -rf /build_zone
EXPOSE 80
CMD R -e "options('shiny.port'=80,shiny.host='0.0.0.0');kaspbeerypi::run_app()"
