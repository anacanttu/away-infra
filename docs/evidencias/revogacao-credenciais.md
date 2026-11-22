# Revogação das credenciais expostas no `Backend-AWAY`

Registro de acompanhamento do incidente descrito em [`../errata.md`](../errata.md). Será atualizado **depois da entrega** (22/11/2026), quando cada item for verificado.

| Item | Ação | Data | Resultado |
|---|---|---|---|
| Senha do RDS antigo (Ohio) | Trocar a senha ou apagar o banco | _pendente_ | _pendente_ |
| Senha da VM `98.83.35.183` | Trocar a senha ou apagar a VM | _pendente_ | _pendente_ |
| Certificados e chaves de `certs/` | Remover como confiáveis dos computadores, se instalados | _pendente_ | _pendente_ |
| Mesma senha em outros serviços | Trocar | _pendente_ | _pendente_ |
| Histórico do Git do `Backend-AWAY` | Decidir entre reescrever o histórico (`git filter-repo` + *force push*) ou aceitar o risco após a revogação | _pendente_ | _pendente_ |

Consulta feita em 22/11/2026: na conta AWS atual, a região `us-east-2` **não tem** instâncias RDS, EC2 nem ambientes Elastic Beanstalk.
