ALTER TABLE public.accounts DROP CONSTRAINT IF EXISTS accounts_type_check;

ALTER TABLE public.accounts
ADD CONSTRAINT accounts_type_check CHECK (
    type IN (
        'cash',
        'bankAccount',
        'creditCard',
        'debt',
        'investment',
        'portfolio',
        'thaiPortfolio',
        'asset'
    )
);
