# Diagrama de despliegue — X-Road Metrics (Escenario B, producción recomendada)

![Diagrama de despliegue](diagrama-despliegue.png)

Fuente editable en Mermaid (se renderiza directamente en GitHub):

```mermaid
flowchart TB
    subgraph XROAD["PLATAFORMA X-ROAD EXISTENTE"]
        CS["Central Server<br/>configuración global · internalconf :80"]
        SSMon["Security Server<br/>cliente de monitoreo<br/>(puerta de entrada)"]
        SS1["Security Servers de miembros<br/>con OpMon habilitado"]
        SSMon -->|"tráfico X-Road :5500<br/>getSecurityServerOperationalData"| SS1
    end

    subgraph PRIV["VLAN PRIVADA — datos confidenciales"]
        subgraph APP["xroad-metrics-app"]
            COL["Collector<br/>cron cada 2–3 h"]
            COR["Corrector<br/>servicio continuo"]
            REP["Reports<br/>cron mensual · PDF/CSV"]
        end
        subgraph DB["xroad-metrics-db · replica set x3"]
            MONGO[("MongoDB 7/8 :27017<br/>raw_messages · clean_data")]
        end
        ANON["xroad-metrics-anon<br/>Anonymizer · cron diario"]
        COL --> MONGO
        COR --> MONGO
        REP --> MONGO
        ANON -->|"lee clean_data"| MONGO
    end

    subgraph PUB["VLAN PÚBLICA / DMZ — datos anonimizados"]
        subgraph OD["xroad-metrics-opendata"]
            PG[("PostgreSQL 14–18 :5432<br/>datos anonimizados")]
            WEB["Opendata<br/>Web UI + API · HTTPS :443"]
            WEB --> PG
        end
        VIZ["xroad-metrics-viz<br/>Networking / Visualizer (R Shiny)<br/>HTTPS :443"]
        VIZ -->|"lee últimos 30 días"| PG
    end

    USR["Usuarios / público"] -->|"HTTPS :443"| WEB
    USR -->|"HTTPS :443"| VIZ
    OPS["Operador X-Road"] -->|"informes por correo / ficheros"| REP

    COL -->|"HTTP :80 internalconf<br/>lista de Security Servers"| CS
    COL -->|"X-Road vía SS :80/443 (mTLS)"| SSMon
    ANON ==>|"ÚNICO flujo privado → público<br/>solo datos anonimizados · :5432"| PG

    classDef priv fill:#eef4ff,stroke:#3366cc;
    classDef pub fill:#eefbf0,stroke:#2e8b57;
    class APP,DB priv;
    class OD pub;
```

## Notas de implementación
- Todos los hosts: Ubuntu Server 22.04/24.04 LTS, NTP activo, nombres según `04-diseno-despliegue.md`.
- MongoDB en replica set de 3 nodos en producción (en el dibujo se agrupa como un solo bloque lógico).
- El Anonymizer es el **único** componente con conectividad entre zonas, y solo hacia PostgreSQL:5432.
- Para el piloto (Escenario A) todo el bloque privado cabe en un host y el público en otro — o se omite hasta la fase 2.
