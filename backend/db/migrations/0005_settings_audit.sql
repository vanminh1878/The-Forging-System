-- CFG-01: the first tenant override must be audited too, without duplicating UPDATE audit.
CREATE OR REPLACE FUNCTION fn_system_configs_audit() RETURNS trigger AS $$
DECLARE previous_value jsonb;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.value IS NOT DISTINCT FROM OLD.value THEN RETURN NEW; END IF;
    previous_value := OLD.value;
  END IF;
  INSERT INTO audit_logs (tenant_id,actor_id,actor_type,action,entity_type,entity_id,before_data,after_data,reason)
  VALUES (NEW.tenant_id,NEW.updated_by,CASE WHEN NEW.updated_by IS NULL THEN 'SYSTEM' ELSE 'USER' END,
    'CONFIG_CHANGE','SYSTEM_CONFIG',NEW.key,previous_value,NEW.value,
    NULLIF(current_setting('app.config_change_reason',true),''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_system_configs_audit_insert AFTER INSERT ON system_configs
  FOR EACH ROW EXECUTE FUNCTION fn_system_configs_audit();
