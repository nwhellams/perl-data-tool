FROM perl:5.38-slim

WORKDIR /app

# System deps for building DBD::Pg (libpq) + basic build tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install CPAN deps from cpanfile
COPY cpanfile /app/cpanfile
RUN cpanm --notest --installdeps /app

# Copy configuration files
ADD conf /app/conf

# Copy the script
COPY export_data_to_excel.pl /app/export_data_to_excel.pl
RUN chmod +x /app/export_data_to_excel.pl

# Sensible defaults (compose will override as needed)
ENV PGHOST=postgres \
    PGPORT=5432 \
    PGDATABASE=demo \
    PGUSER=demo \
    PGPASSWORD=demo
