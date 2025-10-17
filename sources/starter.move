module petrolera::petrolera {

    use std::string::String;
    use sui::vec_map::{VecMap, Self};

    // --- CODIGOS DE ERROR CON MENSAJES CLAROS ---
    #[error]
    const ERR_BARRIL_EXISTE: vector<u8> = b"ERROR: Ya existe un barril con este ID.";
    #[error]
    const ERR_BARRIL_NO_EXISTE: vector<u8> = b"ERROR: El barril no existe en los productos.";
    #[error]
    const ERR_ID_PRODUCTO_EXISTE: vector<u8> = b"ERROR: El ID del producto ya esta en uso.";
    #[error]
    const ERR_PLATAFORMA_NO_EXISTE: vector<u8> = b"ERROR: La plataforma no existe.";
    #[error]
    const ERR_REFINERIA_NO_EXISTE: vector<u8> = b"ERROR: La refineria no existe.";
    #[error]
    const ERR_DINERO_INSUFICIENTE: vector<u8> = b"ERROR: Dinero insuficiente!!!!";
    

    // --- CONTADORES INDEPENDIENTES PARA CADA TIPO DE ID AUTOINCREMENTALES ---
    public struct ContadorIds has store {
        ultimo_id_refineria: u8,
        ultimo_id_barril: u8,
        ultimo_id_plataforma: u8,
        ultimo_id_producto: u8, // lo comparten petroquímicos, asfaltos, combustibles
    }


    // --- ESTRUCTURAS PRINCIPALES ---
    //LA PETROLERA
    public struct Petrolera has key, store {
        id: UID,
        nombre: String,
        productos: VecMap<u8, Producto>, 
        barriles: VecMap<u8, Barril>,      
        plataformas: VecMap<u8, Plataforma>,  
        refinerias: VecMap<u8, Refineria>,
        dinero: u64,
        contador_ids: ContadorIds,
    }

    //ESTRUCTURA DE PLATAFORMA
    public struct Plataforma has copy, drop, store {
        id: u8,
        nombre: String,
        capacidad: u8, // Capacidad de barriles que puede extraer en una operacion
        costo: u64,
    }

    //ESTRUCTURA DE REFINERIA
    public struct Refineria has copy, drop, store {
        id: u8,
        nombre: String,
        costo: u64,
    }

    //ESTRUCTURAS DE PRODUCCION
    public struct Barril has copy, drop, store {
        id: u8,
        litros: u8,
        precio: u8,
    }

    public enum Producto has copy, drop, store {
        Petroquimico(Petroquimico),
        Asfalto(Asfalto),
        Combustible(Combustible),
    }

    public struct Petroquimico has copy, drop, store {
        id: u8,
        nombre: String,
        precio: u8,
    }

    public struct Asfalto has copy, drop, store {
        id: u8,
        tipo: String,
        precio: u8,
    }

    public struct Combustible has copy, drop, store {
        id: u8,
        tipo: String,
        precio: u8,
    }


    // --- FUNCIONES DE CREACION Y CONTADORES ---

    // --- PETROLERA ---
    #[allow(lint(self_transfer))]
    public fun crear_petrolera(nombre: String, ctx: &mut TxContext){
        let petrolera = Petrolera {
                            id: object::new(ctx),
                            nombre,
                            barriles: vec_map::empty(),
                            productos: vec_map::empty(),
                            plataformas: vec_map::empty(),
                            refinerias: vec_map::empty(),
                            dinero: 20000000000,//20 mil millones de dolares
                            contador_ids: ContadorIds {
                            ultimo_id_refineria: 0,
                            ultimo_id_barril: 0,
                            ultimo_id_plataforma: 0,
                            ultimo_id_producto: 0,
                        },
        };
        transfer::transfer(petrolera, tx_context::sender(ctx));
    }


    // --- FUNCIONES PARA INSTANCIAR OBJETOS --- metodo create del crud
    //INSTALAR UNA PLATAFORMA PARA PRODUCIR BARRILES
    public fun agregar_plataforma(petrolera: &mut Petrolera, nombre: String) {
        let id_plataforma = obtener_id_plataforma(petrolera);
        let _plataforma = Plataforma {
            id: id_plataforma,
            nombre,
            capacidad: 1,
            costo: 10000000000, //10 mil millones de dolares
        };
        assert!(petrolera.dinero >= _plataforma.costo, ERR_DINERO_INSUFICIENTE);
        petrolera.dinero = petrolera.dinero - _plataforma.costo;
        petrolera.plataformas.insert(id_plataforma, _plataforma);
    }

    //INSTALAR UNA REFINERIA PARA PROCESAR BARRILES EN VARIOS PRODUCTOS
    public fun agregar_refineria(petrolera: &mut Petrolera, nombre: String) {
        let id_refineria = obtener_id_refineria(petrolera);
        let refineria = Refineria {
            id: id_refineria,
            nombre,
            costo: 7000000000, //7 mil millones de dolares
        };
        assert!(petrolera.dinero >= refineria.costo, ERR_DINERO_INSUFICIENTE);
        petrolera.dinero = petrolera.dinero - refineria.costo;
        petrolera.refinerias.insert(id_refineria, refineria);
    }

    // -- METODOS AUXILIARES DE OBTENCION DE IDs autoincrementales  ---
    public fun obtener_id_refineria(petrolera: &mut Petrolera): u8 {
        let nuevo_id = petrolera.contador_ids.ultimo_id_refineria + 1;
        petrolera.contador_ids.ultimo_id_refineria = nuevo_id;
        nuevo_id
    }

    public fun obtener_id_barril(petrolera: &mut Petrolera): u8 {
        let nuevo_id = petrolera.contador_ids.ultimo_id_barril + 1;
        petrolera.contador_ids.ultimo_id_barril = nuevo_id;
        nuevo_id
    }

    public fun obtener_id_plataforma(petrolera: &mut Petrolera): u8 {
        let nuevo_id = petrolera.contador_ids.ultimo_id_plataforma + 1;
        petrolera.contador_ids.ultimo_id_plataforma = nuevo_id;
        nuevo_id
    }

    public fun obtener_id_producto(petrolera: &mut Petrolera): u8 {
        let nuevo_id = petrolera.contador_ids.ultimo_id_producto + 1;
        petrolera.contador_ids.ultimo_id_producto = nuevo_id;
        nuevo_id
    }


    // --- FUNCIONES DE LOGICA DE NEGOCIO ---   metodo create del crud
    //--- EXTRACCION DE PETROLEO, INICIALMENTE PRODUCE 1 BARRIL CADA LLAMADO ---
    public fun extraer_petroleo(petrolera: &mut Petrolera, plataforma_id: u8) {
        assert!(petrolera.plataformas.contains(&plataforma_id), ERR_PLATAFORMA_NO_EXISTE);

        let plataforma = petrolera.plataformas.get(&plataforma_id);//traigo la plataforma
        let capacidad_plataforma = plataforma.capacidad;//traigo la capacidad de plataforma
        let mut barriles_trabajados = 0;//inicio variable de barriles trabajados

        while (barriles_trabajados < capacidad_plataforma) {
            barriles_trabajados = barriles_trabajados + 1;
            let barril_id = obtener_id_barril(petrolera);
            let barril = Barril { id: barril_id, litros: 159, precio: 60 };//creo el barril

            assert!(!petrolera.barriles.contains(&barril_id), ERR_BARRIL_EXISTE);
            petrolera.barriles.insert(barril_id, barril);
        };
    }


    //--- DESTILACION DE BARRIL EN REFINERIA --- combina create y delete
    //SE ELIMINA UN BARRIL Y SE CREAN 1 PETROQUIMICO,1 ASFALTO Y 1 COMBUSTIBLE
    public fun destilar_barril(
        petrolera: &mut Petrolera, 
        refineria_id: u8, 
        barril_id: u8, 
        nombre_petroquimico: String,
        tipo_asfalto: String,
        tipo_combustible: String
    ) {
        assert!(petrolera.refinerias.contains(&refineria_id), ERR_REFINERIA_NO_EXISTE);
        assert!(petrolera.barriles.contains(&barril_id), ERR_BARRIL_NO_EXISTE);

        //SE ELIMINA EL BARRIL DURANTE LA PRODUCCION
        petrolera.barriles.remove(&barril_id);
        //GENERACION DE IDs
        let petroquimico_id = obtener_id_producto(petrolera);
        let asfalto_id = obtener_id_producto(petrolera);
        let combustible_id = obtener_id_producto(petrolera);
        //SE CREAN LOS PRODUCTOS EN BASE AL BARRIL
        let petro = Producto::Petroquimico(Petroquimico { id: petroquimico_id, nombre: nombre_petroquimico, precio: 40 });
        let asfalt = Producto::Asfalto(Asfalto { id: asfalto_id, tipo: tipo_asfalto, precio: 30 });
        let comb = Producto::Combustible(Combustible { id: combustible_id, tipo: tipo_combustible, precio: 80 });

        //SE ALMACENAN LOS PRODUCTOS CREADOS
        assert!(!petrolera.productos.contains(&petroquimico_id), ERR_ID_PRODUCTO_EXISTE);
        petrolera.productos.insert(petroquimico_id, petro);

        assert!(!petrolera.productos.contains(&asfalto_id), ERR_ID_PRODUCTO_EXISTE);
        petrolera.productos.insert(asfalto_id, asfalt);

        assert!(!petrolera.productos.contains(&combustible_id), ERR_ID_PRODUCTO_EXISTE);
        petrolera.productos.insert(combustible_id, comb);
    }


    // METODOS DELETE DEL CRUD
    // --- FUNCIONES ADMINISTRATIVAS

    // VENDER TODOS LOS PRODUCTOS   
    public fun vender_todos_los_productos(petrolera: &mut Petrolera) {
        let mut total_ganancias: u64 = 0;
        let producto_ids = vec_map::keys(&petrolera.productos);
        let lenght = vector::length(&producto_ids);
        let mut i = 0;
        while (i < lenght) {
            let producto_id = *vector::borrow(&producto_ids, i);
            let _producto = petrolera.productos.get(&producto_id);
            let ganancia = match (_producto) {
                Producto::Petroquimico(p) => p.precio as u64,
                Producto::Asfalto(a) => a.precio as u64,
                Producto::Combustible(c) => c.precio as u64,
            };
            total_ganancias = total_ganancias + ganancia;
            i = i + 1;
        };
        petrolera.productos = vec_map::empty();
        petrolera.dinero = petrolera.dinero + total_ganancias;
    }
    //VENDER TODOS LOS BARRILES
    public fun vender_todos_los_barriles(petrolera: &mut Petrolera) {
        let mut total_ganancias: u64 = 0;
        let barriles_ids = vec_map::keys(&petrolera.barriles);
        let length = vector::length(&barriles_ids);
        let mut i = 0;
        while (i < length) {
            let barril_id = *vector::borrow(&barriles_ids, i);
            let _barril = petrolera.barriles.get(&barril_id);
            // Suma el precio del barril convertido a u64
            total_ganancias = total_ganancias + (_barril.precio as u64);
            i = i + 1;
        };
        // Vaciado el VecMap de barriles reemplazándolo por uno vacío
        petrolera.barriles = vec_map::empty();
        // Suma las ganancias al dinero total de la petrolera
        petrolera.dinero = petrolera.dinero + total_ganancias;
    }

    //VENDER TODO (PRODUCTOS Y BARRILES)
    public fun vender_todo(petrolera: &mut Petrolera) {
        vender_todos_los_productos(petrolera);
        vender_todos_los_barriles(petrolera);
    }

    //DESMONTAR
    public fun desmontar_plataforma(petrolera: &mut Petrolera, plataforma_id: u8) {
        assert!(petrolera.plataformas.contains(&plataforma_id), ERR_PLATAFORMA_NO_EXISTE);
        petrolera.plataformas.remove(&plataforma_id);
    }
    public fun desmontar_refineria(petrolera: &mut Petrolera, refineria_id: u8) {
        assert!(petrolera.refinerias.contains(&refineria_id), ERR_REFINERIA_NO_EXISTE);
        petrolera.refinerias.remove(&refineria_id);
    }


    //METODOS DE UPDATE DEL CRUD
    //RENOMBRAR PLATAFORMA Y REFINERIA
    public fun renombrar_plataforma(petrolera: &mut Petrolera, plataforma_id: u8, nuevo_nombre: String) {
        assert!(petrolera.plataformas.contains(&plataforma_id), ERR_PLATAFORMA_NO_EXISTE);
        let plataforma = petrolera.plataformas.get_mut(&plataforma_id);
        plataforma.nombre = nuevo_nombre;
    }

    public fun renombrar_refineria(petrolera: &mut Petrolera, refineria_id: u8, nuevo_nombre: String) {
        assert!(petrolera.refinerias.contains(&refineria_id), ERR_REFINERIA_NO_EXISTE);
        let refineria = petrolera.refinerias.get_mut(&refineria_id);
        refineria.nombre = nuevo_nombre;
    }

    //INVERTIR MEJORA DE CAPACIDAD EN PLATAFORMA (MEJORA EN 5 LA CAPACIDAD, CUESTA 2 MIL MILLONES)
    public fun mejorar_capacidad_plataforma(petrolera: &mut Petrolera, plataforma_id: u8) {
        assert!(petrolera.plataformas.contains(&plataforma_id), ERR_PLATAFORMA_NO_EXISTE);
        let plataforma = petrolera.plataformas.get_mut(&plataforma_id);
        let costo_mejora: u64 = 2000000000; //2 mil millones de dolares
        assert!(petrolera.dinero >= costo_mejora, ERR_DINERO_INSUFICIENTE);
        plataforma.capacidad = plataforma.capacidad + 5;
        petrolera.dinero = petrolera.dinero - costo_mejora;
    }   


}