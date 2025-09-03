# SQL Server Pre-Aggregate Demo 🚀

Bu repo, **SQL sorgularında %90’a kadar performans iyileştirmesi sağlayabilen** klasik ama çoğunlukla unutulmuş bir deseni göstermektedir:  
👉 **N+1 alt sorgu** yerine **önceden agregasyon + JOIN** yaklaşımı.

## 🎯 Amaç

- N+1 alt sorguların (korelasyonlu subquery) performans tuzağını göstermek  
- Pre-aggregate + JOIN yaklaşımı ile **dramatic hız kazanımını** ispatlamak  
- Indexed View (SQL Server’daki materialized view) ile dashboard hızlandırmayı göstermek  

Bu repo, [“Sorgu Süresini %90 Azaltan SQL Deseni”]([https://yigit-katircioglu.medium.com/sorgu-s%C3%BCresini-90-azaltan-sql-%C3%A7al%C4%B1%C5%9Fmalar%C4%B1-cte-405b24ca59dc]) blog yazısını desteklemek için hazırlanmıştır.

---

## 📂 İçindekiler

- `demo.sql` → Tek parça T-SQL scripti  
  - Demo veritabanı oluşturur  
  - 100K `Users`, 8M `Orders` üretir  
  - Versiyon A: N+1 Subquery  
  - Versiyon B: Pre-Aggregate + JOIN  
  - Versiyon C: Indexed View (NOEXPAND)  

---

## 🔧 Kullanım

1. **Repo’yu klonla**  
   ```bash
   git clone https://github.com/kullanici/sql-server-preaggregate-demo.git
   cd sql-server-preaggregate-demo
