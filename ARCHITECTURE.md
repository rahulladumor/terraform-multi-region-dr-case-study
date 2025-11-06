# Architecture Diagrams - Multi-Region Disaster Recovery

Comprehensive Mermaid diagrams for the enterprise multi-region DR infrastructure.

## 1. Multi-Region Active-Active Architecture

```mermaid
graph TB
    subgraph Global Services
        R53[Route 53<br/>Health-based Routing<br/>Latency-based Routing]
        CF[CloudFront<br/>Global CDN<br/>Origin Failover]
    end
    
    subgraph Primary Region - us-east-1
        subgraph US-East Network
            VPC1[VPC 10.0.0.0/16]
            ALB1[Application LB<br/>Multi-AZ]
            EC2-1[EC2 Fleet<br/>Auto Scaling]
        end
        
        subgraph US-East Data
            Aurora1[Aurora Global DB<br/>PRIMARY<br/>Write Endpoint]
            DDB1[DynamoDB<br/>Global Table<br/>us-east-1]
            S3-1[S3 Bucket<br/>CRR Enabled]
        end
    end
    
    subgraph Secondary Region - us-west-2
        subgraph US-West Network
            VPC2[VPC 10.1.0.0/16]
            ALB2[Application LB<br/>Multi-AZ]
            EC2-2[EC2 Fleet<br/>Auto Scaling]
        end
        
        subgraph US-West Data
            Aurora2[Aurora Global DB<br/>SECONDARY<br/>Read Endpoint]
            DDB2[DynamoDB<br/>Global Table<br/>us-west-2]
            S3-2[S3 Bucket<br/>CRR Destination]
        end
    end
    
    subgraph DR Region - eu-west-1
        subgraph EU-West Network
            VPC3[VPC 10.2.0.0/16]
            ALB3[Application LB<br/>Multi-AZ]
            EC2-3[EC2 Fleet<br/>Auto Scaling]
        end
        
        subgraph EU-West Data
            Aurora3[Aurora Global DB<br/>SECONDARY<br/>Read Endpoint]
            DDB3[DynamoDB<br/>Global Table<br/>eu-west-1]
            S3-3[S3 Bucket<br/>CRR Destination]
        end
    end
    
    R53 -->|Health Check OK| CF
    CF -->|Primary| ALB1
    CF -.->|Failover| ALB2
    CF -.->|Failover| ALB3
    
    ALB1 --> EC2-1
    ALB2 --> EC2-2
    ALB3 --> EC2-3
    
    EC2-1 -->|Read/Write| Aurora1
    EC2-2 -->|Read Only| Aurora2
    EC2-3 -->|Read Only| Aurora3
    
    Aurora1 -.->|<1s Replication| Aurora2
    Aurora1 -.->|<1s Replication| Aurora3
    
    EC2-1 -->|Write| DDB1
    EC2-2 -->|Write| DDB2
    EC2-3 -->|Write| DDB3
    
    DDB1 <-.->|Bi-directional Sync| DDB2
    DDB1 <-.->|Bi-directional Sync| DDB3
    DDB2 <-.->|Bi-directional Sync| DDB3
    
    S3-1 -.->|Async Replication| S3-2
    S3-1 -.->|Async Replication| S3-3
```

## 2. Aurora Global Database Replication

```mermaid
sequenceDiagram
    participant App1 as App (us-east-1)
    participant Primary as Aurora Primary<br/>us-east-1
    participant Secondary1 as Aurora Secondary<br/>us-west-2
    participant Secondary2 as Aurora Secondary<br/>eu-west-1
    participant App2 as App (us-west-2)
    participant App3 as App (eu-west-1)
    
    Note over Primary: Write Region
    App1->>Primary: 1. Write Transaction
    Primary->>Primary: 2. Commit to Storage
    
    par Physical Replication
        Primary-->>Secondary1: 3a. Replicate (< 1 second)
        Primary-->>Secondary2: 3b. Replicate (< 1 second)
    end
    
    Primary-->>App1: 4. Write Acknowledged
    
    Note over Secondary1,Secondary2: Read Replicas
    App2->>Secondary1: 5a. Read Query (low latency)
    App3->>Secondary2: 5b. Read Query (low latency)
    
    Secondary1-->>App2: 6a. Return Data
    Secondary2-->>App3: 6b. Return Data
    
    Note over Primary: Region Failure Scenario
    rect rgb(255, 100, 100)
        Primary->>Primary: ❌ FAILURE
    end
    
    Note over Secondary1: Promote to Primary
    Secondary1->>Secondary1: 7. Promoted to Primary
    App1->>Secondary1: 8. Redirect Writes
    Secondary1-->>App1: 9. New Primary Active
```

## 3. DynamoDB Global Tables

```mermaid
graph TB
    subgraph Applications
        App1[App us-east-1<br/>Write/Read]
        App2[App us-west-2<br/>Write/Read]
        App3[App eu-west-1<br/>Write/Read]
    end
    
    subgraph Global Table - "orders"
        Table1[DynamoDB Table<br/>us-east-1<br/>Replica 1]
        Table2[DynamoDB Table<br/>us-west-2<br/>Replica 2]
        Table3[DynamoDB Table<br/>eu-west-1<br/>Replica 3]
    end
    
    subgraph Replication
        Stream1[DynamoDB Streams<br/>Change Data Capture]
        Conflict[Conflict Resolution<br/>Last Write Wins]
    end
    
    App1 -->|Write| Table1
    App2 -->|Write| Table2
    App3 -->|Write| Table3
    
    App1 -->|Read| Table1
    App2 -->|Read| Table2
    App3 -->|Read| Table3
    
    Table1 -->|Changes| Stream1
    Table2 -->|Changes| Stream1
    Table3 -->|Changes| Stream1
    
    Stream1 -->|Replicate| Table1
    Stream1 -->|Replicate| Table2
    Stream1 -->|Replicate| Table3
    
    Stream1 --> Conflict
    
    Note1[Typical Replication: <1 second<br/>Strong Eventual Consistency]
```

## 4. Route 53 Health-Based Failover

```mermaid
graph TB
    subgraph DNS Configuration
        R53[Route 53<br/>Hosted Zone]
        Record[A Record: app.example.com]
    end
    
    subgraph Health Checks
        HC1[Health Check 1<br/>us-east-1<br/>✅ Healthy]
        HC2[Health Check 2<br/>us-west-2<br/>✅ Healthy]
        HC3[Health Check 3<br/>eu-west-1<br/>✅ Healthy]
    end
    
    subgraph Routing Policies
        Primary[Primary: us-east-1<br/>Weight: 70]
        Secondary[Secondary: us-west-2<br/>Weight: 20]
        DR[DR: eu-west-1<br/>Weight: 10]
    end
    
    subgraph Load Balancers
        ALB1[ALB us-east-1<br/>app-lb-1.elb.amazonaws.com]
        ALB2[ALB us-west-2<br/>app-lb-2.elb.amazonaws.com]
        ALB3[ALB eu-west-1<br/>app-lb-3.elb.amazonaws.com]
    end
    
    R53 --> Record
    Record --> HC1
    Record --> HC2
    Record --> HC3
    
    HC1 -->|Healthy| Primary
    HC2 -->|Healthy| Secondary
    HC3 -->|Healthy| DR
    
    Primary --> ALB1
    Secondary --> ALB2
    DR --> ALB3
    
    HC1 -.->|Every 30s| ALB1
    HC2 -.->|Every 30s| ALB2
    HC3 -.->|Every 30s| ALB3
    
    style HC1 fill:#90EE90
    style HC2 fill:#90EE90
    style HC3 fill:#90EE90
```

## 5. Failover Scenario - Primary Region Failure

```mermaid
sequenceDiagram
    participant User
    participant R53 as Route 53
    participant HC as Health Checks
    participant Primary as us-east-1<br/>(PRIMARY)
    participant Secondary as us-west-2<br/>(STANDBY)
    participant Aurora as Aurora Global DB
    
    Note over Primary: Normal Operation
    User->>R53: 1. DNS Query
    R53->>HC: 2. Check Health
    HC->>Primary: 3. Health Check
    Primary-->>HC: 4. ✅ Healthy
    R53-->>User: 5. Return Primary IP
    User->>Primary: 6. Request
    Primary-->>User: 7. Response
    
    Note over Primary: Region Failure
    rect rgb(255, 100, 100)
        Primary->>Primary: ❌ OUTAGE
    end
    
    HC->>Primary: 8. Health Check
    Primary--xHC: 9. ❌ Failed (3 consecutive)
    HC->>R53: 10. Mark Primary Unhealthy
    
    Note over Secondary: Automatic Failover
    User->>R53: 11. DNS Query
    R53->>HC: 12. Check Health
    HC->>Secondary: 13. Health Check
    Secondary-->>HC: 14. ✅ Healthy
    R53-->>User: 15. Return Secondary IP
    
    User->>Secondary: 16. Request (redirected)
    Secondary->>Aurora: 17. Promote Secondary DB
    Aurora-->>Secondary: 18. Promoted to Primary
    Secondary-->>User: 19. Response
    
    Note over Secondary: RTO: < 5 minutes<br/>RPO: < 1 minute
```

## 6. S3 Cross-Region Replication

```mermaid
graph LR
    subgraph Source - us-east-1
        S3Source[S3 Bucket<br/>app-data-us-east-1<br/>Versioning Enabled]
        Objects[Objects<br/>- images/<br/>- documents/<br/>- backups/]
    end
    
    subgraph Replication
        Rule[Replication Rule<br/>Replicate All Objects<br/>Async Replication]
        IAM[IAM Role<br/>s3:ReplicateObject]
        KMS[KMS Encryption<br/>Cross-region Keys]
    end
    
    subgraph Destination 1 - us-west-2
        S3Dest1[S3 Bucket<br/>app-data-us-west-2<br/>Versioning Enabled]
    end
    
    subgraph Destination 2 - eu-west-1
        S3Dest2[S3 Bucket<br/>app-data-eu-west-1<br/>Versioning Enabled]
    end
    
    subgraph Monitoring
        Metrics[CloudWatch Metrics<br/>Replication Time<br/>Replication Status]
        Alarms[CloudWatch Alarms<br/>Replication Lag >15min]
    end
    
    Objects --> S3Source
    S3Source -->|Trigger| Rule
    Rule -->|Use| IAM
    Rule -->|Encrypt| KMS
    
    Rule -.->|Async Copy| S3Dest1
    Rule -.->|Async Copy| S3Dest2
    
    Rule --> Metrics
    Metrics --> Alarms
```

## 7. Disaster Recovery Testing Flow

```mermaid
graph TB
    subgraph Planning
        Plan[DR Plan Document<br/>RTO: <5min<br/>RPO: <1min]
        Schedule[Test Schedule<br/>Quarterly]
    end
    
    subgraph Test Execution
        T1[Step 1: Notify Team<br/>Scheduled DR Test]
        T2[Step 2: Simulate Primary Failure<br/>Disable Health Checks]
        T3[Step 3: Monitor Failover<br/>Route 53, Aurora Promotion]
        T4[Step 4: Verify Secondary<br/>All Services Operational]
        T5[Step 5: Measure Metrics<br/>RTO, RPO Validation]
        T6[Step 6: Restore Primary<br/>Fail Back Test]
    end
    
    subgraph Validation
        V1[✅ DNS Failover: <1min]
        V2[✅ Aurora Promotion: <2min]
        V3[✅ App Available: <3min]
        V4[✅ Data Consistent]
        V5[✅ RTO Met: <5min]
        V6[✅ RPO Met: <1min]
    end
    
    subgraph Documentation
        Report[DR Test Report<br/>Success/Failures]
        Lessons[Lessons Learned<br/>Improvements]
        Update[Update DR Plan<br/>New Procedures]
    end
    
    Plan --> T1
    Schedule --> T1
    
    T1 --> T2
    T2 --> T3
    T3 --> T4
    T4 --> T5
    T5 --> T6
    
    T3 --> V1
    T3 --> V2
    T4 --> V3
    T5 --> V4
    T5 --> V5
    T5 --> V6
    
    V6 --> Report
    Report --> Lessons
    Lessons --> Update
```

## 8. Cost Distribution Across Regions

```mermaid
pie title Monthly DR Cost Breakdown ($1,400)
    "Aurora Global DB (3 regions)" : 600
    "EC2 Auto Scaling (3 regions)" : 300
    "DynamoDB Global Tables" : 200
    "S3 Cross-Region Replication" : 100
    "Data Transfer (inter-region)" : 120
    "Route 53 Health Checks" : 30
    "CloudFront Distribution" : 50
```

## 9. Monitoring & Alerting Architecture

```mermaid
graph TB
    subgraph Data Sources
        R53M[Route 53<br/>Health Check Metrics]
        AuroraM[Aurora<br/>Replication Lag]
        DDBM[DynamoDB<br/>Replication Latency]
        S3M[S3<br/>Replication Status]
        EC2M[EC2<br/>Instance Health]
    end
    
    subgraph CloudWatch
        CW[CloudWatch<br/>Central Monitoring]
        Dashboard[Dashboard<br/>Multi-Region View]
        
        Alarm1[Alarm: Health Check Failed<br/>3 consecutive failures]
        Alarm2[Alarm: Aurora Lag >5s<br/>Replication Issue]
        Alarm3[Alarm: DynamoDB Lag >1s<br/>Table Replication]
        Alarm4[Alarm: S3 Replication >15min<br/>Object Copy Delay]
    end
    
    subgraph Alerting
        SNS[SNS Topic<br/>DR-Alerts]
        Email[Email<br/>DevOps Team]
        PagerDuty[PagerDuty<br/>On-Call Engineer]
        Slack[Slack<br/>#dr-alerts]
        Lambda[Lambda<br/>Auto-Remediation]
    end
    
    R53M --> CW
    AuroraM --> CW
    DDBM --> CW
    S3M --> CW
    EC2M --> CW
    
    CW --> Dashboard
    CW --> Alarm1
    CW --> Alarm2
    CW --> Alarm3
    CW --> Alarm4
    
    Alarm1 --> SNS
    Alarm2 --> SNS
    Alarm3 --> SNS
    Alarm4 --> SNS
    
    SNS --> Email
    SNS --> PagerDuty
    SNS --> Slack
    SNS --> Lambda
```

## 10. RTO & RPO Metrics

```mermaid
graph LR
    subgraph Recovery Objectives
        RTO[RTO Target<br/>< 5 minutes<br/>Recovery Time Objective]
        RPO[RPO Target<br/>< 1 minute<br/>Recovery Point Objective]
    end
    
    subgraph RTO Components
        DNS[DNS Failover<br/>1 minute<br/>Route 53 TTL]
        DB[DB Promotion<br/>2 minutes<br/>Aurora Global]
        App[App Startup<br/>1 minute<br/>Auto Scaling]
        Validate[Validation<br/>1 minute<br/>Health Checks]
    end
    
    subgraph RPO Components
        AuroraRPO[Aurora Replication<br/>< 1 second<br/>Physical Replication]
        DDBRPO[DynamoDB Replication<br/>< 1 second<br/>Global Tables]
        S3RPO[S3 Replication<br/>< 15 minutes<br/>Async CRR]
    end
    
    subgraph Achieved Metrics
        RTOActual[Actual RTO<br/>4 minutes<br/>✅ Under Target]
        RPOActual[Actual RPO<br/>45 seconds<br/>✅ Under Target]
    end
    
    RTO --> DNS
    DNS --> DB
    DB --> App
    App --> Validate
    Validate --> RTOActual
    
    RPO --> AuroraRPO
    RPO --> DDBRPO
    RPO --> S3RPO
    S3RPO --> RPOActual
```

---

## Key Features

### 1. Multi-Region Active-Active
- 3 AWS regions: us-east-1, us-west-2, eu-west-1
- Active traffic in all regions
- Weighted routing (70/20/10)

### 2. Data Replication
- **Aurora Global Database**: <1 second RPO
- **DynamoDB Global Tables**: Sub-second replication
- **S3 Cross-Region Replication**: Async backup

### 3. Automatic Failover
- **Route 53**: Health-based routing
- **CloudFront**: Origin failover
- **Aurora**: Automatic promotion

### 4. Recovery Objectives
- **RTO**: <5 minutes
- **RPO**: <1 minute
- Validated through quarterly DR tests

### 5. Cost Optimization
- Right-sized instances per region
- DynamoDB on-demand pricing
- S3 lifecycle policies

---

**Author**: Rahul Ladumor  
**License**: MIT 2025
