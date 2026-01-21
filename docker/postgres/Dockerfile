FROM postgres:17-alpine

# 환경 변수 (docker-compose.yml에서 오버라이드 가능)
ENV POSTGRES_DB=vt_benchmark
ENV POSTGRES_USER=vt_user
ENV POSTGRES_PASSWORD=vt_password

# PostgreSQL 설정 파일 복사
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 초기화 스크립트 복사 (실행 순서대로)
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY seed-data.sql /docker-entrypoint-initdb.d/02-seed-data.sql

# PostgreSQL을 custom config로 실행
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
